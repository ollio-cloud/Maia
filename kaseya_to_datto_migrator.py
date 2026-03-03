#!/usr/bin/env python3
"""
Kaseya to Datto RMM Migration Tool
Converts Kaseya VSA Agent Procedures (XML) to Datto RMM Components (.CPT)

Features:
- Automatic strategy detection (unconditional/conditional/simple)
- Variable transformation (#var# -> $env:var)
- File operation pattern removal (WriteFile/ExecuteFile/DeleteFile)
- Script type detection and mapping
- File dependency tracking and documentation
"""

import xml.etree.ElementTree as ET
import zipfile
import json
import re
import os
import uuid
import hashlib
from pathlib import Path, PureWindowsPath
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, field
from enum import Enum

# Configuration
INPUT_XML_PATH = "/mnt/c/wsl-files/Kaseya___Agent_Procedure_Export.xml"
OUTPUT_BASE_DIR = "/mnt/c/wsl-files/datto_migration_output"


class MigrationStrategy(Enum):
    """Migration strategy for each procedure"""
    SEPARATE_COMPONENTS = "separate_components"  # Unconditional ExecuteScript -> separate Datto components
    MONOLITHIC = "monolithic"  # Simple procedure -> single PowerShell script
    ORCHESTRATOR = "orchestrator"  # Conditional ExecuteScript -> orchestrator + .ps1 files


@dataclass
class FileDependency:
    """Tracks a file dependency from VSASharedFiles"""
    original_path: str  # VSASharedFiles\Applications\...
    filename: str  # Extracted filename
    used_in_statement: str  # Where it's used (WriteFile, ExecuteFile, etc)


@dataclass
class KaseyaProcedure:
    """Represents a Kaseya procedure"""
    name: str
    procedure_id: str
    description: str
    xml_body: ET.Element
    strategy: Optional[MigrationStrategy] = None
    nested_procedures: List[str] = field(default_factory=list)
    file_dependencies: List[FileDependency] = field(default_factory=list)
    variables: List[str] = field(default_factory=list)
    has_conditionals: bool = False
    statements: List[ET.Element] = field(default_factory=list)


@dataclass
class DattoComponent:
    """Represents a Datto RMM component"""
    name: str
    description: str
    script_content: str
    script_type: str = "powershell"  # powershell, batch, vbscript
    included_ps1_files: Dict[str, str] = field(default_factory=dict)  # filename -> content
    file_dependencies: List[FileDependency] = field(default_factory=list)
    timeout: int = 3600
    security_level: int = 2


class KaseyaXMLParser:
    """Parses Kaseya XML export"""

    def __init__(self, xml_path: str):
        self.xml_path = xml_path
        self.tree = ET.parse(xml_path)
        self.root = self.tree.getroot()
        self.procedures: Dict[str, KaseyaProcedure] = {}

    def parse_all_procedures(self) -> Dict[str, KaseyaProcedure]:
        """Parse all procedures from XML"""
        namespaces = {'ns': 'http://www.kaseya.com/vsa/2008/12/Scripting'}

        for proc_elem in self.root.findall('.//ns:Procedure', namespaces):
            proc = self._parse_procedure(proc_elem, namespaces)
            self.procedures[proc.procedure_id] = proc

        return self.procedures

    def _parse_procedure(self, proc_elem: ET.Element, ns: dict) -> KaseyaProcedure:
        """Parse a single procedure"""
        name = proc_elem.get('name', 'Unnamed')
        proc_id = proc_elem.get('id', str(uuid.uuid4()))

        body = proc_elem.find('ns:Body', ns)
        description = body.get('description', '') if body is not None else ''

        proc = KaseyaProcedure(
            name=name,
            procedure_id=proc_id,
            description=description,
            xml_body=body if body is not None else proc_elem
        )

        # Analyze procedure structure
        self._analyze_procedure(proc, body if body is not None else proc_elem, ns)

        return proc

    def _analyze_procedure(self, proc: KaseyaProcedure, body: ET.Element, ns: dict):
        """Analyze procedure to determine strategy and extract info"""

        # Find all statements
        proc.statements = body.findall('.//ns:Statement', ns)

        # Check for conditionals (If/Else)
        if_elements = body.findall('.//ns:If', ns)
        proc.has_conditionals = len(if_elements) > 0

        # Find ExecuteScript statements
        for stmt in proc.statements:
            if stmt.get('name') == 'ExecuteScript':
                script_name_param = stmt.find('.//ns:Parameter[@name="ScriptName"]', ns)
                if script_name_param is not None:
                    proc.nested_procedures.append(script_name_param.get('value', ''))

            # Find WriteFile operations (file dependencies)
            elif stmt.get('name') == 'WriteFile':
                self._extract_file_dependency(stmt, proc, ns)

            # Find GetVariable operations (variables)
            elif stmt.get('name') == 'GetVariable':
                var_name_param = stmt.find('.//ns:Parameter[@name="VariableName"]', ns)
                if var_name_param is not None:
                    proc.variables.append(var_name_param.get('value', ''))

        # Determine strategy
        proc.strategy = self._determine_strategy(proc)

    def _extract_file_dependency(self, stmt: ET.Element, proc: KaseyaProcedure, ns: dict):
        """Extract file dependency from WriteFile statement"""
        path_param = stmt.find('.//ns:Parameter[@name="Path"]', ns)
        managed_file_param = stmt.find('.//ns:Parameter[@name="ManagedFile"]', ns)

        if managed_file_param is not None:
            original_path = managed_file_param.get('value', '')
            filename = Path(original_path).name

            dep = FileDependency(
                original_path=original_path,
                filename=filename,
                used_in_statement="WriteFile"
            )
            proc.file_dependencies.append(dep)

    def _determine_strategy(self, proc: KaseyaProcedure) -> MigrationStrategy:
        """Determine migration strategy for procedure"""

        # Has nested procedures with conditionals -> Orchestrator
        if proc.nested_procedures and proc.has_conditionals:
            return MigrationStrategy.ORCHESTRATOR

        # Has nested procedures without conditionals -> Separate components
        elif proc.nested_procedures and not proc.has_conditionals:
            return MigrationStrategy.SEPARATE_COMPONENTS

        # Simple procedure -> Monolithic
        else:
            return MigrationStrategy.MONOLITHIC


class ScriptTransformer:
    """Transforms Kaseya scripts to Datto PowerShell/Batch"""

    def __init__(self):
        self.namespaces = {'ns': 'http://www.kaseya.com/vsa/2008/12/Scripting'}

    def transform_procedure(self, proc: KaseyaProcedure, all_procedures: Dict[str, KaseyaProcedure]) -> DattoComponent:
        """Transform Kaseya procedure to Datto component"""

        if proc.strategy == MigrationStrategy.MONOLITHIC:
            return self._transform_monolithic(proc)
        elif proc.strategy == MigrationStrategy.ORCHESTRATOR:
            return self._transform_orchestrator(proc, all_procedures)
        else:  # SEPARATE_COMPONENTS
            return self._transform_separate_components(proc, all_procedures)

    def _transform_monolithic(self, proc: KaseyaProcedure) -> DattoComponent:
        """Transform to single monolithic PowerShell script"""

        script_lines = []
        script_lines.append(f"# Migrated from Kaseya procedure: {proc.name}")
        script_lines.append(f"# Original ID: {proc.procedure_id}")
        script_lines.append(f"# Migration Strategy: Monolithic PowerShell")
        script_lines.append("")

        # Add file dependency comments
        if proc.file_dependencies:
            script_lines.append("# " + "=" * 77)
            script_lines.append("# FILE DEPENDENCIES - ACTION REQUIRED AFTER IMPORT")
            script_lines.append("# " + "=" * 77)
            for dep in proc.file_dependencies:
                script_lines.append(f"# FILE: {dep.filename}")
                script_lines.append(f"# SOURCE: {dep.original_path}")
                script_lines.append("# ACTION: Manually source this file and add it to the Datto component")
            script_lines.append("# " + "=" * 77)
            script_lines.append("")

        # Transform statements
        script_lines.extend(self._transform_statements(proc.xml_body, proc))

        component = DattoComponent(
            name=proc.name,
            description=proc.description or f"Migrated from Kaseya: {proc.name}",
            script_content="\n".join(script_lines),
            file_dependencies=proc.file_dependencies
        )

        return component

    def _transform_orchestrator(self, proc: KaseyaProcedure, all_procedures: Dict[str, KaseyaProcedure]) -> DattoComponent:
        """Transform to orchestrator script + included .ps1 files"""

        script_lines = []
        script_lines.append(f"# Orchestrator Script - Migrated from Kaseya: {proc.name}")
        script_lines.append(f"# Original ID: {proc.procedure_id}")
        script_lines.append(f"# Migration Strategy: Orchestrator + Included PS1 Files")
        script_lines.append("")

        # Generate orchestrator logic
        included_files = {}
        script_lines.extend(self._transform_conditional_logic(proc.xml_body, proc, included_files, all_procedures))

        component = DattoComponent(
            name=proc.name,
            description=proc.description or f"Migrated from Kaseya: {proc.name}",
            script_content="\n".join(script_lines),
            included_ps1_files=included_files,
            file_dependencies=proc.file_dependencies
        )

        return component

    def _transform_separate_components(self, proc: KaseyaProcedure, all_procedures: Dict[str, KaseyaProcedure]) -> DattoComponent:
        """Transform to indicate separate components needed"""

        script_lines = []
        script_lines.append(f"# Migrated from Kaseya procedure: {proc.name}")
        script_lines.append(f"# Original ID: {proc.procedure_id}")
        script_lines.append(f"# Migration Strategy: Separate Components (Job-based)")
        script_lines.append("")
        script_lines.append("# ============================================================================")
        script_lines.append("# MIGRATION NOTE: This procedure calls other procedures unconditionally.")
        script_lines.append("# Recommended Datto structure:")
        script_lines.append("#   - Create a Datto JOB (equivalent to Kaseya policy)")
        script_lines.append("#   - Add the following procedures as separate COMPONENTS in that job:")
        script_lines.append("# ============================================================================")
        script_lines.append("")

        for nested_proc_name in proc.nested_procedures:
            script_lines.append(f"#   - {nested_proc_name}")

        script_lines.append("")
        script_lines.append("# All components will execute in sequence automatically.")
        script_lines.append("")

        # Still include the main procedure logic
        script_lines.extend(self._transform_statements(proc.xml_body, proc))

        component = DattoComponent(
            name=proc.name,
            description=proc.description or f"Migrated from Kaseya: {proc.name}",
            script_content="\n".join(script_lines),
            file_dependencies=proc.file_dependencies
        )

        return component

    def _transform_statements(self, body: ET.Element, proc: KaseyaProcedure) -> List[str]:
        """Transform Kaseya statements to PowerShell"""
        lines = []

        for stmt in body.findall('.//ns:Statement', self.namespaces):
            stmt_name = stmt.get('name', '')

            if stmt_name == 'WriteFile':
                # Skip WriteFile - files will be in working directory
                lines.append("# WriteFile operation removed - file will be in Datto working directory")

            elif stmt_name == 'DeleteFile':
                # Skip DeleteFile - cleanup not needed in Datto
                lines.append("# DeleteFile operation removed - Datto handles cleanup")

            elif stmt_name == 'ExecuteFile':
                lines.extend(self._transform_execute_file(stmt))

            elif stmt_name == 'GetVariable':
                lines.extend(self._transform_get_variable(stmt))

            elif stmt_name == 'WriteScriptLogEntry':
                lines.extend(self._transform_log_entry(stmt))

            else:
                lines.append(f"# TODO: Unsupported statement type: {stmt_name}")

        return lines

    def _transform_execute_file(self, stmt: ET.Element) -> List[str]:
        """Transform ExecuteFile statement"""
        lines = []

        path_param = stmt.find('.//ns:Parameter[@name="Path"]', self.namespaces)
        args_param = stmt.find('.//ns:Parameter[@name="Arguments"]', self.namespaces)

        if path_param is not None:
            path = path_param.get('value', '')
            args = args_param.get('value', '') if args_param is not None else ''

            # Check if path is a system path/executable (keep as-is) or component file (extract filename only)
            # System paths: Windows, System32, Program Files, system executables
            path_lower = path.lower()
            is_system_path = any(x in path_lower for x in [
                '%windir%', '%systemroot%', '%programfiles%',
                'c:\\windows\\', 'c:\\program files\\',
                '\\windows\\system32\\', '\\system32\\',
                'msiexec.exe', 'cmd.exe', 'powershell.exe', 'cscript.exe', 'wscript.exe'
            ])

            # Additional check: if path starts with c:\temp, c:\users, etc. it's a component file
            is_component_file = any(path_lower.startswith(x) for x in [
                'c:\\temp\\', 'c:\\users\\', 'c:\\programdata\\',  # Note: single backslash in raw string
                '#', '$env:'  # Variable-based paths are component files
            ]) or any(path.startswith(x) for x in ['#', '$env:'])

            # Extract filename if this is a component file path (not system)
            if (not is_system_path or is_component_file) and ('\\' in path or '/' in path):
                # Use PureWindowsPath to correctly handle Windows paths on Linux
                path = PureWindowsPath(path).name

            # Transform arguments - replace file paths with filenames only
            # Pattern: #var#path\file.ext or c:\path\file.ext → file.ext
            args = self._transform_file_paths_in_args(args)

            if args:
                lines.append(f"& {path} {args}")
            else:
                lines.append(f"& {path}")

        return lines

    def _transform_file_paths_in_args(self, args: str) -> str:
        """Transform file paths in arguments to filenames only, transform variables"""

        # First, transform Kaseya variables (#var#)
        args = self._transform_variables(args)

        # Now replace any file paths (with variable or not) to just filenames
        # Pattern: drive:\path\file.ext → file.ext
        # Pattern: $env:var\path\file.ext → file.ext

        # Find patterns like: $env:agentDrvtemp\file.msi or C:\path\file.exe
        import re

        # Match: $env:varname\path\file.ext or drive:\path\file.ext
        pattern = r'(\$env:\w+|[A-Za-z]:)([\\\/][\w\s\.\-]+)*[\\\/]([\w\.\-]+\.\w+)'

        def replace_with_filename(match):
            # Return just the filename (last group)
            return match.group(3)

        args = re.sub(pattern, replace_with_filename, args)

        return args

    def _transform_get_variable(self, stmt: ET.Element) -> List[str]:
        """Transform GetVariable statement"""
        lines = []

        var_name_param = stmt.find('.//ns:Parameter[@name="VariableName"]', self.namespaces)
        var_type_param = stmt.find('.//ns:Parameter[@name="VariableType"]', self.namespaces)
        source_param = stmt.find('.//ns:Parameter[@name="SourceContent"]', self.namespaces)

        if var_name_param is not None and var_type_param is not None:
            var_name = var_name_param.get('value', '')
            var_type = var_type_param.get('value', '')

            # Map Kaseya variable types to PowerShell
            if var_type == 'AgentInstallDrive':
                lines.append(f"$env:{var_name} = $env:SystemDrive + '\\'")
            elif var_type == 'AgentTempSystemDirectory':
                lines.append(f"$env:{var_name} = $env:TEMP")
            elif var_type == 'RegistryValue' and source_param is not None:
                reg_path = source_param.get('value', '')
                lines.append(f"$env:{var_name} = Get-ItemProperty -Path '{reg_path}' | Select-Object -ExpandProperty Value")
            else:
                lines.append(f"# TODO: GetVariable type '{var_type}' for variable '{var_name}'")

        return lines

    def _transform_log_entry(self, stmt: ET.Element) -> List[str]:
        """Transform WriteScriptLogEntry"""
        comment_param = stmt.find('.//ns:Parameter[@name="Comment"]', self.namespaces)
        if comment_param is not None:
            comment = comment_param.get('value', '')
            return [f'Write-Output "{comment}"']
        return []

    def _transform_conditional_logic(self, body: ET.Element, proc: KaseyaProcedure,
                                    included_files: Dict[str, str],
                                    all_procedures: Dict[str, KaseyaProcedure]) -> List[str]:
        """Transform conditional If/Else logic with ExecuteScript"""
        lines = []

        for if_elem in body.findall('.//ns:If', self.namespaces):
            condition = if_elem.find('ns:Condition', self.namespaces)
            then_elem = if_elem.find('ns:Then', self.namespaces)
            else_elem = if_elem.find('ns:Else', self.namespaces)

            # Transform condition
            condition_code = self._transform_condition(condition)
            lines.append(f"if ({condition_code}) {{")

            # Transform Then block
            if then_elem is not None:
                lines.extend(self._transform_block(then_elem, included_files, all_procedures, indent="    "))

            # Transform Else block
            if else_elem is not None:
                lines.append("} else {")
                lines.extend(self._transform_block(else_elem, included_files, all_procedures, indent="    "))

            lines.append("}")

        return lines

    def _transform_condition(self, condition: ET.Element) -> str:
        """Transform Kaseya condition to PowerShell"""
        if condition is None:
            return "$true"

        condition_name = condition.get('name', '')

        if condition_name == 'True':
            return "$true"
        elif condition_name == 'TestRegistryKey':
            path_param = condition.find('.//ns:Parameter[@name="Path"]', self.namespaces)
            if path_param is not None:
                reg_path = path_param.get('value', '')
                return f"Test-Path -Path '{reg_path}'"

        return f"$true  # TODO: Condition '{condition_name}' not implemented"

    def _transform_block(self, block: ET.Element, included_files: Dict[str, str],
                         all_procedures: Dict[str, KaseyaProcedure], indent: str) -> List[str]:
        """Transform Then/Else block"""
        lines = []

        for stmt in block.findall('ns:Statement', self.namespaces):
            if stmt.get('name') == 'ExecuteScript':
                # Generate .ps1 file reference
                script_name_param = stmt.find('.//ns:Parameter[@name="ScriptName"]', self.namespaces)
                if script_name_param is not None:
                    script_name = script_name_param.get('value', '')
                    ps1_filename = self._sanitize_filename(script_name) + ".ps1"

                    lines.append("")
                    lines.append(indent + "# " + "=" * 73)
                    lines.append(indent + f"# FILE DEPENDENCY: {ps1_filename}")
                    lines.append(indent + "# ACTION REQUIRED:")
                    lines.append(indent + "#   1. Manually create or source this procedure from Kaseya")
                    lines.append(indent + f"#   2. Add {ps1_filename} to this Datto component")
                    lines.append(indent + "# " + "=" * 73)
                    lines.append(indent + f"& .\\{ps1_filename}")

                    # Create placeholder .ps1 file
                    included_files[ps1_filename] = f"# Placeholder for nested procedure: {script_name}\n# TODO: Migrate this procedure separately"

        return lines

    def _transform_variables(self, text: str) -> str:
        """Transform Kaseya variables (#var#) to PowerShell ($env:var)"""
        # Pattern: #variableName#
        pattern = r'#(\w+)#'

        def replace_var(match):
            var_name = match.group(1)
            return f"$env:{var_name}"

        return re.sub(pattern, replace_var, text)

    def _sanitize_filename(self, name: str) -> str:
        """Sanitize filename for Windows"""
        # Remove invalid characters
        name = re.sub(r'[<>:"/\\|?*]', '_', name)
        # Replace spaces with underscores
        name = name.replace(' ', '_')
        return name


class DattoCPTGenerator:
    """Generates Datto .CPT files"""

    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.components_dir = self.output_dir / "components"
        self.dependencies_dir = self.output_dir / "dependencies"
        self.scripts_dir = self.output_dir / "included_scripts"

        # Create directories
        self.components_dir.mkdir(parents=True, exist_ok=True)
        self.dependencies_dir.mkdir(parents=True, exist_ok=True)
        self.scripts_dir.mkdir(parents=True, exist_ok=True)

    def generate_cpt(self, component: DattoComponent, proc_name: str) -> Path:
        """Generate .CPT file for component"""

        sanitized_name = self._sanitize_filename(proc_name)
        cpt_path = self.components_dir / f"{sanitized_name}.cpt"

        # Create temporary directory for CPT contents
        import tempfile
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Write command.bat (always contains the script, regardless of type)
            command_path = temp_path / "command.bat"
            command_path.write_text(component.script_content, encoding='utf-8')

            # Write resource.xml
            resource_xml = self._generate_resource_xml(component, proc_name)
            resource_path = temp_path / "resource.xml"
            resource_path.write_text(resource_xml, encoding='utf-8')

            # Write included .ps1 files
            for ps1_name, ps1_content in component.included_ps1_files.items():
                ps1_path = temp_path / ps1_name
                ps1_path.write_text(ps1_content, encoding='utf-8')

                # Also save to included_scripts folder for reference
                proc_scripts_dir = self.scripts_dir / sanitized_name
                proc_scripts_dir.mkdir(exist_ok=True)
                (proc_scripts_dir / ps1_name).write_text(ps1_content, encoding='utf-8')

            # Create ZIP file (.cpt)
            with zipfile.ZipFile(cpt_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for file_path in temp_path.iterdir():
                    if file_path.is_file():
                        zipf.write(file_path, file_path.name)

        # Generate dependencies file
        if component.file_dependencies:
            self._generate_dependencies_file(component, sanitized_name)

        return cpt_path

    def _generate_resource_xml(self, component: DattoComponent, proc_name: str) -> str:
        """Generate resource.xml content"""

        # Map script type
        install_type_map = {
            'powershell': 'powershell',
            'batch': 'batch',
            'vbscript': 'vbscript'
        }
        install_type = install_type_map.get(component.script_type, 'powershell')

        # Generate UUID
        component_uuid = str(uuid.uuid4())

        # Generate hash (dummy for now)
        content_hash = hashlib.md5(component.script_content.encode()).hexdigest()

        xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<component info="CentraStage Component">
    <general>
        <name>{self._xml_escape(proc_name)}</name>
        <category>scripts</category>
        <description>{self._xml_escape(component.description[:200])}</description>
        <uid>{component_uuid}</uid>
        <hash>{content_hash}</hash>
        <version>1</version>
        <timeout>{component.timeout}</timeout>
        <securityLevel>{component.security_level}</securityLevel>
        <installType>{install_type}</installType>
    </general>
</component>'''

        return xml

    def _generate_dependencies_file(self, component: DattoComponent, sanitized_name: str):
        """Generate FILE_DEPENDENCIES.txt"""

        dep_path = self.dependencies_dir / f"{sanitized_name}_DEPENDENCIES.txt"

        lines = []
        lines.append("=" * 80)
        lines.append(f"FILE DEPENDENCIES FOR: {component.name}")
        lines.append("=" * 80)
        lines.append("")
        lines.append("The following files must be manually sourced from Kaseya VSASharedFiles")
        lines.append("and added to this Datto component AFTER importing the .CPT file.")
        lines.append("")
        lines.append("-" * 80)

        for i, dep in enumerate(component.file_dependencies, 1):
            lines.append(f"\n{i}. {dep.filename}")
            lines.append(f"   Source: {dep.original_path}")
            lines.append(f"   Used in: {dep.used_in_statement}")

        lines.append("\n" + "-" * 80)
        lines.append("\nPOST-IMPORT STEPS:")
        lines.append("=" * 80)
        lines.append(f"1. Locate the above file(s) in Kaseya VSASharedFiles")
        lines.append(f"2. Open the imported Datto component: '{component.name}'")
        lines.append(f"3. Click 'Edit Component'")
        lines.append(f"4. Add each required file to the component's file attachments")
        lines.append(f"5. Save the component")
        lines.append(f"6. Test execution on a non-production machine")
        lines.append("")

        dep_path.write_text("\n".join(lines), encoding='utf-8')

    def _xml_escape(self, text: str) -> str:
        """Escape XML special characters"""
        text = text.replace('&', '&amp;')
        text = text.replace('<', '&lt;')
        text = text.replace('>', '&gt;')
        text = text.replace('"', '&quot;')
        text = text.replace("'", '&apos;')
        return text

    def _sanitize_filename(self, name: str) -> str:
        """Sanitize filename"""
        name = re.sub(r'[<>:"/\\|?*]', '_', name)
        name = name.replace(' ', '_')
        return name


class MigrationReporter:
    """Generates migration reports"""

    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.report_data = {
            'total_procedures': 0,
            'strategies': {
                'monolithic': 0,
                'orchestrator': 0,
                'separate_components': 0
            },
            'procedures': [],
            'errors': []
        }

    def add_procedure(self, proc: KaseyaProcedure, cpt_path: Optional[Path] = None, error: Optional[str] = None):
        """Add procedure to report"""

        self.report_data['total_procedures'] += 1

        if error:
            self.report_data['errors'].append({
                'procedure': proc.name,
                'id': proc.procedure_id,
                'error': error
            })
        else:
            strategy_name = proc.strategy.value if proc.strategy else 'unknown'
            self.report_data['strategies'][strategy_name] = self.report_data['strategies'].get(strategy_name, 0) + 1

            self.report_data['procedures'].append({
                'name': proc.name,
                'id': proc.procedure_id,
                'strategy': strategy_name,
                'nested_procedures': len(proc.nested_procedures),
                'file_dependencies': len(proc.file_dependencies),
                'has_conditionals': proc.has_conditionals,
                'cpt_file': str(cpt_path.name) if cpt_path else None
            })

    def generate_markdown_report(self) -> Path:
        """Generate markdown migration report"""

        report_path = self.output_dir / "migration_report.md"

        lines = []
        lines.append("# Kaseya to Datto RMM Migration Report")
        lines.append("")
        lines.append(f"**Generated:** {self._get_timestamp()}")
        lines.append("")

        # Summary
        lines.append("## Summary")
        lines.append("")
        lines.append(f"- **Total Procedures:** {self.report_data['total_procedures']}")
        lines.append(f"- **Successfully Migrated:** {len(self.report_data['procedures'])}")
        lines.append(f"- **Errors:** {len(self.report_data['errors'])}")
        lines.append("")

        # Strategy Breakdown
        lines.append("## Migration Strategies")
        lines.append("")
        lines.append("| Strategy | Count | Description |")
        lines.append("|----------|-------|-------------|")
        lines.append(f"| Monolithic | {self.report_data['strategies'].get('monolithic', 0)} | Single PowerShell script |")
        lines.append(f"| Orchestrator | {self.report_data['strategies'].get('orchestrator', 0)} | Main script + included .ps1 files |")
        lines.append(f"| Separate Components | {self.report_data['strategies'].get('separate_components', 0)} | Multiple Datto components in a job |")
        lines.append("")

        # Procedure Details
        lines.append("## Migrated Procedures")
        lines.append("")
        lines.append("| Procedure Name | Strategy | Nested | Files | CPT File |")
        lines.append("|----------------|----------|--------|-------|----------|")

        for proc in self.report_data['procedures']:
            lines.append(f"| {proc['name']} | {proc['strategy']} | {proc['nested_procedures']} | {proc['file_dependencies']} | {proc['cpt_file']} |")

        lines.append("")

        # Errors
        if self.report_data['errors']:
            lines.append("## Errors")
            lines.append("")
            for error in self.report_data['errors']:
                lines.append(f"### {error['procedure']} (ID: {error['id']})")
                lines.append(f"```")
                lines.append(error['error'])
                lines.append(f"```")
                lines.append("")

        # Next Steps
        lines.append("## Next Steps")
        lines.append("")
        lines.append("1. **Review Generated Components**")
        lines.append("   - Check `components/` directory for .CPT files")
        lines.append("   - Review `included_scripts/` for reference .ps1 files")
        lines.append("")
        lines.append("2. **Handle File Dependencies**")
        lines.append("   - Check `dependencies/` directory for *_DEPENDENCIES.txt files")
        lines.append("   - Source required files from Kaseya VSASharedFiles")
        lines.append("   - Add files to Datto components post-import")
        lines.append("")
        lines.append("3. **Import to Datto RMM**")
        lines.append("   - Import .CPT files into Datto RMM")
        lines.append("   - Follow post-import steps in dependency files")
        lines.append("")
        lines.append("4. **Test Components**")
        lines.append("   - Test each component on non-production machines")
        lines.append("   - Verify conditional logic execution")
        lines.append("   - Validate file dependencies are accessible")
        lines.append("")

        report_path.write_text("\n".join(lines), encoding='utf-8')

        return report_path

    def generate_json_analysis(self) -> Path:
        """Generate JSON strategy analysis"""

        json_path = self.output_dir / "strategy_analysis.json"

        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(self.report_data, f, indent=2)

        return json_path

    def _get_timestamp(self) -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def main():
    """Main migration workflow"""

    print("=" * 80)
    print("Kaseya to Datto RMM Migration Tool")
    print("=" * 80)
    print()

    # Initialize components
    print(f"[1/5] Parsing Kaseya XML: {INPUT_XML_PATH}")
    parser = KaseyaXMLParser(INPUT_XML_PATH)
    procedures = parser.parse_all_procedures()
    print(f"      Found {len(procedures)} procedures")
    print()

    print(f"[2/5] Analyzing migration strategies...")
    transformer = ScriptTransformer()
    generator = DattoCPTGenerator(OUTPUT_BASE_DIR)
    reporter = MigrationReporter(OUTPUT_BASE_DIR)

    # Strategy breakdown
    strategies = {'monolithic': 0, 'orchestrator': 0, 'separate_components': 0}
    for proc in procedures.values():
        if proc.strategy:
            strategies[proc.strategy.value] += 1

    print(f"      Monolithic: {strategies['monolithic']}")
    print(f"      Orchestrator: {strategies['orchestrator']}")
    print(f"      Separate Components: {strategies['separate_components']}")
    print()

    print(f"[3/5] Transforming procedures to Datto components...")
    success_count = 0
    error_count = 0

    for i, proc in enumerate(procedures.values(), 1):
        try:
            # Transform
            component = transformer.transform_procedure(proc, procedures)

            # Generate CPT
            cpt_path = generator.generate_cpt(component, proc.name)

            # Report
            reporter.add_procedure(proc, cpt_path)

            success_count += 1

            if i % 25 == 0:
                print(f"      Progress: {i}/{len(procedures)} procedures processed...")

        except Exception as e:
            error_count += 1
            reporter.add_procedure(proc, error=str(e))
            print(f"      ERROR: {proc.name}: {str(e)}")

    print(f"      Completed: {success_count} successful, {error_count} errors")
    print()

    print(f"[4/5] Generating reports...")
    report_md = reporter.generate_markdown_report()
    report_json = reporter.generate_json_analysis()
    print(f"      Migration report: {report_md}")
    print(f"      Strategy analysis: {report_json}")
    print()

    print(f"[5/5] Migration complete!")
    print()
    print("=" * 80)
    print("Output Structure:")
    print("=" * 80)
    print(f"  Components:    {generator.components_dir}")
    print(f"  Dependencies:  {generator.dependencies_dir}")
    print(f"  Scripts:       {generator.scripts_dir}")
    print(f"  Reports:       {OUTPUT_BASE_DIR}")
    print()
    print("Next Steps:")
    print("  1. Review migration_report.md for detailed analysis")
    print("  2. Check dependencies/ folder for file requirements")
    print("  3. Import .CPT files into Datto RMM")
    print("  4. Add required files per *_DEPENDENCIES.txt instructions")
    print("=" * 80)


if __name__ == "__main__":
    main()
