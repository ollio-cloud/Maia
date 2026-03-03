#!/bin/bash
# =============================================================================
# KD Bus Sites VPN Migration - Azure Route Table Script
# CR-2026-002
# Generated: 2026-02-02
# =============================================================================
#
# This script adds routes for all 24 KD Bus sites (71 subnets) to both
# Azure route tables for FortiGate VPN connectivity.
#
# Usage:
#   ./azure-route-table-script.sh [phase]
#
# Examples:
#   ./azure-route-table-script.sh          # Run all phases
#   ./azure-route-table-script.sh pilot    # Run Phase 1 only (Malaga-Morley)
#   ./azure-route-table-script.sh batch1   # Run Phase 2 only (Batch 1)
#   ./azure-route-table-script.sh batch2   # Run Phase 3 only (Batch 2)
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Appropriate permissions on route tables
#
# =============================================================================

# Configuration
EAST_RG="KD-Prod-RG"
EAST_RT="KD-Prod-RouteTable"
EAST_NEXTHOP="10.200.1.68"

SEAST_RG="KD-Mel-RG"
SEAST_RT="KD-Mel-RouteTable"
SEAST_NEXTHOP="10.201.1.68"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to add route to both route tables
add_route() {
    local SITE_NAME=$1
    local ROUTE_NAME=$2
    local ADDRESS_PREFIX=$3

    log_info "Adding route: $ROUTE_NAME ($ADDRESS_PREFIX) for $SITE_NAME"

    # Add to Azure East route table
    az network route-table route create \
        --resource-group "$EAST_RG" \
        --route-table-name "$EAST_RT" \
        --name "$ROUTE_NAME" \
        --address-prefix "$ADDRESS_PREFIX" \
        --next-hop-type VirtualAppliance \
        --next-hop-ip-address "$EAST_NEXTHOP" \
        --output none 2>/dev/null

    if [ $? -eq 0 ]; then
        log_success "  ✓ Added to $EAST_RT"
    else
        log_error "  ✗ Failed to add to $EAST_RT"
    fi

    # Add to Azure South East route table
    az network route-table route create \
        --resource-group "$SEAST_RG" \
        --route-table-name "$SEAST_RT" \
        --name "$ROUTE_NAME" \
        --address-prefix "$ADDRESS_PREFIX" \
        --next-hop-type VirtualAppliance \
        --next-hop-ip-address "$SEAST_NEXTHOP" \
        --output none 2>/dev/null

    if [ $? -eq 0 ]; then
        log_success "  ✓ Added to $SEAST_RT"
    else
        log_error "  ✗ Failed to add to $SEAST_RT"
    fi
}

# =============================================================================
# PHASE 1 - PILOT (Malaga-Morley) - 2 subnets
# =============================================================================
phase1_pilot() {
    echo ""
    echo "============================================================================="
    echo -e "${GREEN}PHASE 1 - PILOT: Malaga-Morley (2 subnets)${NC}"
    echo "============================================================================="

    # Malaga-Morley
    add_route "Malaga-Morley" "Malaga-Morley-Net1" "10.9.52.0/24"
    add_route "Malaga-Morley" "Malaga-Morley-Net2" "10.91.52.0/24"

    log_success "Phase 1 (Pilot) complete: 2 subnets added"
}

# =============================================================================
# PHASE 2 - BATCH 1 (NSW/QLD/SA) - 43 subnets
# =============================================================================
phase2_batch1() {
    echo ""
    echo "============================================================================="
    echo -e "${BLUE}PHASE 2 - BATCH 1: NSW/QLD/SA Sites (43 subnets)${NC}"
    echo "============================================================================="

    # Belmont North (3 subnets)
    echo ""
    log_info "Site: Belmont North (3 subnets)"
    add_route "Belmont-North" "Belmont-North-Net1" "10.21.52.0/24"
    add_route "Belmont-North" "Belmont-North-Net2" "10.2.52.0/24"
    add_route "Belmont-North" "Belmont-North-Net3" "10.24.52.0/24"

    # Brookvale (7 subnets)
    echo ""
    log_info "Site: Brookvale (7 subnets)"
    add_route "Brookvale" "Brookvale-Net1" "10.2.64.0/24"
    add_route "Brookvale" "Brookvale-Net2" "10.21.64.0/24"
    add_route "Brookvale" "Brookvale-Net3" "10.28.64.0/24"
    add_route "Brookvale" "Brookvale-Net4" "10.25.64.0/24"
    add_route "Brookvale" "Brookvale-Net5" "10.26.64.0/24"
    add_route "Brookvale" "Brookvale-Net6" "10.30.64.0/24"
    add_route "Brookvale" "Brookvale-Net7" "10.31.64.0/24"

    # North Sydney (7 subnets)
    echo ""
    log_info "Site: North Sydney (7 subnets)"
    add_route "North-Sydney" "North-Sydney-Net1" "10.2.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net2" "10.21.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net3" "10.28.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net4" "10.25.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net5" "10.26.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net6" "10.30.68.0/24"
    add_route "North-Sydney" "North-Sydney-Net7" "10.31.68.0/24"

    # Mona Vale (7 subnets)
    echo ""
    log_info "Site: Mona Vale (7 subnets)"
    add_route "Mona-Vale" "Mona-Vale-Net1" "10.2.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net2" "10.21.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net3" "10.28.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net4" "10.25.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net5" "10.26.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net6" "10.30.66.0/24"
    add_route "Mona-Vale" "Mona-Vale-Net7" "10.31.66.0/24"

    # Wickham (3 subnets)
    echo ""
    log_info "Site: Wickham (3 subnets)"
    add_route "Wickham" "Wickham-Net1" "10.2.60.0/24"
    add_route "Wickham" "Wickham-Net2" "10.26.60.0/24"
    add_route "Wickham" "Wickham-Net3" "10.21.60.0/24"

    # Queens Wharf (2 subnets)
    echo ""
    log_info "Site: Queens Wharf (2 subnets)"
    add_route "Queens-Wharf" "Queens-Wharf-Net1" "10.21.54.0/24"
    add_route "Queens-Wharf" "Queens-Wharf-Net2" "10.2.54.0/24"

    # Clontarf (3 subnets)
    echo ""
    log_info "Site: Clontarf (3 subnets)"
    add_route "Clontarf" "Clontarf-Net1" "10.71.52.0/24"
    add_route "Clontarf" "Clontarf-Net2" "10.7.52.0/24"
    add_route "Clontarf" "Clontarf-Net3" "10.75.52.0/24"

    # North Lakes (2 subnets)
    echo ""
    log_info "Site: North Lakes (2 subnets)"
    add_route "North-Lakes" "North-Lakes-Net1" "10.71.56.0/24"
    add_route "North-Lakes" "North-Lakes-Net2" "10.7.56.0/24"

    # Hamilton (5 subnets)
    echo ""
    log_info "Site: Hamilton (5 subnets)"
    add_route "Hamilton" "Hamilton-Net1" "10.21.50.0/24"
    add_route "Hamilton" "Hamilton-Net2" "10.24.50.0/24"
    add_route "Hamilton" "Hamilton-Net3" "10.2.50.0/24"
    add_route "Hamilton" "Hamilton-Net4" "10.27.50.0/24"
    add_route "Hamilton" "Hamilton-Net5" "172.20.120.0/24"

    # Goolwa (2 subnets)
    echo ""
    log_info "Site: Goolwa (2 subnets)"
    add_route "Goolwa" "Goolwa-Net1" "10.81.72.0/24"
    add_route "Goolwa" "Goolwa-Net2" "10.8.72.0/24"

    # Murray Bridge (2 subnets)
    echo ""
    log_info "Site: Murray Bridge (2 subnets)"
    add_route "Murray-Bridge" "Murray-Bridge-Net1" "10.81.58.0/24"
    add_route "Murray-Bridge" "Murray-Bridge-Net2" "10.8.58.0/24"

    log_success "Phase 2 (Batch 1) complete: 43 subnets added"
}

# =============================================================================
# PHASE 3 - BATCH 2 (SA/WA) - 26 subnets
# =============================================================================
phase3_batch2() {
    echo ""
    echo "============================================================================="
    echo -e "${YELLOW}PHASE 3 - BATCH 2: SA/WA Sites (26 subnets)${NC}"
    echo "============================================================================="

    # Mt Barker (2 subnets)
    echo ""
    log_info "Site: Mt Barker (2 subnets)"
    add_route "Mt-Barker" "Mt-Barker-Net1" "10.81.62.0/24"
    add_route "Mt-Barker" "Mt-Barker-Net2" "10.8.62.0/24"

    # Aldgate (2 subnets)
    echo ""
    log_info "Site: Aldgate (2 subnets)"
    add_route "Aldgate" "Aldgate-Net1" "10.81.64.0/24"
    add_route "Aldgate" "Aldgate-Net2" "10.8.64.0/24"

    # Pooraka (2 subnets)
    echo ""
    log_info "Site: Pooraka (2 subnets)"
    add_route "Pooraka" "Pooraka-Net1" "10.81.54.0/24"
    add_route "Pooraka" "Pooraka-Net2" "10.8.54.0/24"

    # Willaston (2 subnets)
    echo ""
    log_info "Site: Willaston (2 subnets)"
    add_route "Willaston" "Willaston-Net1" "10.81.68.0/24"
    add_route "Willaston" "Willaston-Net2" "10.8.68.0/24"

    # Nuriootpa (2 subnets)
    echo ""
    log_info "Site: Nuriootpa (2 subnets)"
    add_route "Nuriootpa" "Nuriootpa-Net1" "10.81.60.0/24"
    add_route "Nuriootpa" "Nuriootpa-Net2" "10.8.60.0/24"

    # Welshpool (3 subnets)
    echo ""
    log_info "Site: Welshpool (3 subnets)"
    add_route "Welshpool" "Welshpool-Net1" "10.91.64.0/24"
    add_route "Welshpool" "Welshpool-Net2" "10.9.64.0/24"
    add_route "Welshpool" "Welshpool-Net3" "10.95.64.0/24"

    # Walliston-Kalamunda (3 subnets)
    echo ""
    log_info "Site: Walliston-Kalamunda (3 subnets)"
    add_route "Walliston-Kalamunda" "Walliston-Kalamunda-Net1" "10.91.66.0/24"
    add_route "Walliston-Kalamunda" "Walliston-Kalamunda-Net2" "10.9.66.0/24"
    add_route "Walliston-Kalamunda" "Walliston-Kalamunda-Net3" "10.9.67.0/24"

    # Bayswater (2 subnets)
    echo ""
    log_info "Site: Bayswater (2 subnets)"
    add_route "Bayswater" "Bayswater-Net1" "10.91.58.0/24"
    add_route "Bayswater" "Bayswater-Net2" "10.9.58.0/24"

    # Forrestfield (2 subnets)
    echo ""
    log_info "Site: Forrestfield (2 subnets)"
    add_route "Forrestfield" "Forrestfield-Net1" "10.41.1.0/24"
    add_route "Forrestfield" "Forrestfield-Net2" "10.91.41.0/24"

    # Redcliffe (2 subnets)
    echo ""
    log_info "Site: Redcliffe (2 subnets)"
    add_route "Redcliffe" "Redcliffe-Net1" "10.9.68.0/24"
    add_route "Redcliffe" "Redcliffe-Net2" "10.91.68.0/24"

    # Geraldton (2 subnets)
    echo ""
    log_info "Site: Geraldton (2 subnets)"
    add_route "Geraldton" "Geraldton-Net1" "10.91.70.0/24"
    add_route "Geraldton" "Geraldton-Net2" "10.9.70.0/24"

    # Henley Brook (2 subnets)
    echo ""
    log_info "Site: Henley Brook (2 subnets)"
    add_route "Henley-Brook" "Henley-Brook-Net1" "10.91.54.0/24"
    add_route "Henley-Brook" "Henley-Brook-Net2" "10.9.54.0/24"

    log_success "Phase 3 (Batch 2) complete: 26 subnets added"
}

# =============================================================================
# ROLLBACK FUNCTIONS
# =============================================================================

delete_route() {
    local ROUTE_NAME=$1

    log_info "Deleting route: $ROUTE_NAME"

    # Delete from Azure East route table
    az network route-table route delete \
        --resource-group "$EAST_RG" \
        --route-table-name "$EAST_RT" \
        --name "$ROUTE_NAME" \
        --output none 2>/dev/null

    # Delete from Azure South East route table
    az network route-table route delete \
        --resource-group "$SEAST_RG" \
        --route-table-name "$SEAST_RT" \
        --name "$ROUTE_NAME" \
        --output none 2>/dev/null

    log_success "  ✓ Deleted from both route tables"
}

rollback_pilot() {
    echo ""
    echo "============================================================================="
    echo -e "${RED}ROLLBACK - PILOT: Malaga-Morley${NC}"
    echo "============================================================================="

    delete_route "Malaga-Morley-Net1"
    delete_route "Malaga-Morley-Net2"

    log_success "Pilot rollback complete"
}

rollback_site() {
    local SITE=$1
    echo ""
    log_warning "Rolling back site: $SITE"

    case $SITE in
        "Malaga-Morley")
            delete_route "Malaga-Morley-Net1"
            delete_route "Malaga-Morley-Net2"
            ;;
        "Belmont-North")
            delete_route "Belmont-North-Net1"
            delete_route "Belmont-North-Net2"
            delete_route "Belmont-North-Net3"
            ;;
        "Brookvale")
            for i in {1..7}; do delete_route "Brookvale-Net$i"; done
            ;;
        "North-Sydney")
            for i in {1..7}; do delete_route "North-Sydney-Net$i"; done
            ;;
        "Mona-Vale")
            for i in {1..7}; do delete_route "Mona-Vale-Net$i"; done
            ;;
        "Wickham")
            for i in {1..3}; do delete_route "Wickham-Net$i"; done
            ;;
        "Queens-Wharf")
            delete_route "Queens-Wharf-Net1"
            delete_route "Queens-Wharf-Net2"
            ;;
        "Clontarf")
            for i in {1..3}; do delete_route "Clontarf-Net$i"; done
            ;;
        "North-Lakes")
            delete_route "North-Lakes-Net1"
            delete_route "North-Lakes-Net2"
            ;;
        "Hamilton")
            for i in {1..5}; do delete_route "Hamilton-Net$i"; done
            ;;
        "Goolwa")
            delete_route "Goolwa-Net1"
            delete_route "Goolwa-Net2"
            ;;
        "Murray-Bridge")
            delete_route "Murray-Bridge-Net1"
            delete_route "Murray-Bridge-Net2"
            ;;
        "Mt-Barker")
            delete_route "Mt-Barker-Net1"
            delete_route "Mt-Barker-Net2"
            ;;
        "Aldgate")
            delete_route "Aldgate-Net1"
            delete_route "Aldgate-Net2"
            ;;
        "Pooraka")
            delete_route "Pooraka-Net1"
            delete_route "Pooraka-Net2"
            ;;
        "Willaston")
            delete_route "Willaston-Net1"
            delete_route "Willaston-Net2"
            ;;
        "Nuriootpa")
            delete_route "Nuriootpa-Net1"
            delete_route "Nuriootpa-Net2"
            ;;
        "Welshpool")
            for i in {1..3}; do delete_route "Welshpool-Net$i"; done
            ;;
        "Walliston-Kalamunda")
            for i in {1..3}; do delete_route "Walliston-Kalamunda-Net$i"; done
            ;;
        "Bayswater")
            delete_route "Bayswater-Net1"
            delete_route "Bayswater-Net2"
            ;;
        "Forrestfield")
            delete_route "Forrestfield-Net1"
            delete_route "Forrestfield-Net2"
            ;;
        "Redcliffe")
            delete_route "Redcliffe-Net1"
            delete_route "Redcliffe-Net2"
            ;;
        "Geraldton")
            delete_route "Geraldton-Net1"
            delete_route "Geraldton-Net2"
            ;;
        "Henley-Brook")
            delete_route "Henley-Brook-Net1"
            delete_route "Henley-Brook-Net2"
            ;;
        *)
            log_error "Unknown site: $SITE"
            ;;
    esac

    log_success "Rollback complete for $SITE"
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    echo "KD Bus Sites VPN Migration - Azure Route Table Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  pilot       Run Phase 1 (Malaga-Morley pilot)"
    echo "  batch1      Run Phase 2 (NSW/QLD/SA sites)"
    echo "  batch2      Run Phase 3 (SA/WA sites)"
    echo "  all         Run all phases"
    echo "  rollback-pilot    Rollback pilot site routes"
    echo "  rollback-site SITE    Rollback specific site (e.g., rollback-site Brookvale)"
    echo "  list        List all route tables"
    echo "  help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 pilot                    # Add pilot site routes"
    echo "  $0 batch1                   # Add Batch 1 routes"
    echo "  $0 all                      # Add all routes"
    echo "  $0 rollback-site Brookvale  # Remove Brookvale routes"
}

list_routes() {
    echo "============================================================================="
    echo "Current routes in $EAST_RT"
    echo "============================================================================="
    az network route-table route list \
        --resource-group "$EAST_RG" \
        --route-table-name "$EAST_RT" \
        --output table

    echo ""
    echo "============================================================================="
    echo "Current routes in $SEAST_RT"
    echo "============================================================================="
    az network route-table route list \
        --resource-group "$SEAST_RG" \
        --route-table-name "$SEAST_RT" \
        --output table
}

# Parse command line arguments
case "${1:-all}" in
    pilot)
        phase1_pilot
        ;;
    batch1)
        phase2_batch1
        ;;
    batch2)
        phase3_batch2
        ;;
    all)
        phase1_pilot
        phase2_batch1
        phase3_batch2
        echo ""
        echo "============================================================================="
        log_success "ALL PHASES COMPLETE: 71 subnets added to both route tables"
        echo "============================================================================="
        ;;
    rollback-pilot)
        rollback_pilot
        ;;
    rollback-site)
        if [ -z "$2" ]; then
            log_error "Please specify a site name"
            exit 1
        fi
        rollback_site "$2"
        ;;
    list)
        list_routes
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac