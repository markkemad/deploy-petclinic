#!/bin/bash

################################################################################
# PetClinic Build and Deploy Script
################################################################################
# Description: Manual build and deployment script that mimics Jenkins pipeline
# Author: DevOps Team
# Version: 1.0
# Usage: bash scripts/build-and-deploy.sh [OPTIONS]
#
# Options:
#   --skip-tests     Skip unit tests during build
#   --no-deploy      Build only, skip deployment
#   --clean          Clean previous builds before building
#   --help           Show this help message
################################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PETCLINIC_SRC="${PROJECT_ROOT}/spring-petclinic"
BUILD_DIR="/home/pet-clinic/build"
WAR_FILE="${BUILD_DIR}/petclinic.war"
JAVA25_HOME="/home/pet-clinic/java/jdk25"
JAVA21_HOME="/home/pet-clinic/java/jdk21"
JAVA_HOME_TOMCAT="/home/pet-clinic/java/jdk25"  # Tomcat 10 uses Java 25
TOMCAT_HOME="/home/pet-clinic/tomcat"
TOMCAT_PORT="9090"
APP_CONTEXT="petclinic"

# Default options
SKIP_TESTS=true
DO_DEPLOY=true
DO_CLEAN=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --run-tests)
            SKIP_TESTS=false
            shift
            ;;
        --no-deploy)
            DO_DEPLOY=false
            shift
            ;;
        --clean)
            DO_CLEAN=true
            shift
            ;;
        --help)
            grep "^#" "$0" | grep -v "^#!/bin/bash" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local FAILED=0
    
    # Check Java 25
    if [ -d "${JAVA25_HOME}" ] && [ -x "${JAVA25_HOME}/bin/java" ]; then
        print_success "Java 25 found: ${JAVA25_HOME}"
    else
        print_error "Java 25 not found at ${JAVA25_HOME}"
        FAILED=$((FAILED + 1))
    fi
    
    # Check Java 21
    if [ -d "${JAVA21_HOME}" ] && [ -x "${JAVA21_HOME}/bin/java" ]; then
        print_success "Java 21 found: ${JAVA21_HOME}"
    else
        print_error "Java 21 not found at ${JAVA21_HOME}"
        FAILED=$((FAILED + 1))
    fi
    
    # Check PetClinic source
    if [ -d "${PETCLINIC_SRC}" ]; then
        print_success "PetClinic source found: ${PETCLINIC_SRC}"
    else
        print_error "PetClinic source not found at ${PETCLINIC_SRC}"
        FAILED=$((FAILED + 1))
    fi
    
    # Check Maven wrapper
    if [ -f "${PETCLINIC_SRC}/mvnw" ]; then
        print_success "Maven wrapper found"
        chmod +x "${PETCLINIC_SRC}/mvnw"
    else
        print_error "Maven wrapper not found"
        FAILED=$((FAILED + 1))
    fi
    
    # Check Tomcat
    if [ -d "${TOMCAT_HOME}" ]; then
        print_success "Tomcat found: ${TOMCAT_HOME}"
    else
        print_warning "Tomcat not found (deployment will fail)"
    fi
    
    # Check Ansible
    if command -v ansible-playbook &> /dev/null; then
        print_success "Ansible installed"
    else
        print_warning "Ansible not installed (deployment will use manual method)"
    fi
    
    if [ $FAILED -gt 0 ]; then
        print_error "Prerequisites check failed. Please fix the issues above."
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

# Build stage
build_application() {
    print_header "Building PetClinic Application"
    
    cd "${PETCLINIC_SRC}"
    
    # Set Java 25 for build
    export JAVA_HOME=${JAVA25_HOME}
    export PATH=${JAVA_HOME}/bin:$PATH
    export MAVEN_OPTS="-Xmx512m"
    
    print_info "Java version:"
    java -version
    
    # Create build directory
    mkdir -p "${BUILD_DIR}"
    
    # Clean if requested
    if [ "$DO_CLEAN" = true ]; then
        print_info "Cleaning previous builds..."
        ./mvnw clean
    fi
    
    # Build
    print_info "Building WAR file..."
    if [ "$SKIP_TESTS" = true ]; then
        print_info "Skipping tests..."
        ./mvnw package -DskipTests
    else
        print_info "Running tests..."
        ./mvnw package
    fi
    
    # Check if WAR was created
    if [ -f target/*.war ]; then
        WAR_NAME=$(ls target/*.war)
        print_success "Build successful: ${WAR_NAME}"
        
        # Copy to build directory
        cp target/*.war "${WAR_FILE}"
        print_success "WAR copied to: ${WAR_FILE}"
        
        # Display WAR info
        WAR_SIZE=$(du -h "${WAR_FILE}" | cut -f1)
        print_info "WAR size: ${WAR_SIZE}"
    else
        print_error "WAR file not created!"
        exit 1
    fi
}

# Deploy stage
deploy_application() {
    if [ "$DO_DEPLOY" = false ]; then
        print_warning "Deployment skipped (--no-deploy flag)"
        return 0
    fi
    
    print_header "Deploying to Tomcat"
    
    # Check if Ansible playbook exists
    ANSIBLE_PLAYBOOK="${PROJECT_ROOT}/ansible/playbooks/deploy_petclinic.yml"
    
    if [ -f "${ANSIBLE_PLAYBOOK}" ] && command -v ansible-playbook &> /dev/null; then
        print_info "Using Ansible for deployment..."
        cd "${PROJECT_ROOT}"
        ansible-playbook ansible/playbooks/deploy_petclinic.yml -v
    else
        print_warning "Ansible not available, using manual deployment..."
        deploy_manually
    fi
}

# Manual deployment (fallback)
deploy_manually() {
    print_info "Performing manual deployment..."
    
    # Check if Tomcat is running
    if [ -f "${TOMCAT_HOME}/tomcat.pid" ]; then
        PID=$(cat "${TOMCAT_HOME}/tomcat.pid")
        if ps -p $PID > /dev/null 2>&1; then
            print_info "Stopping Tomcat..."
            export JAVA_HOME=${JAVA_HOME_TOMCAT}
            export PATH=${JAVA_HOME}/bin:$PATH
            ${TOMCAT_HOME}/bin/shutdown.sh || true
            sleep 5
        fi
    fi
    
    # Remove old application
    print_info "Removing old application..."
    rm -rf "${TOMCAT_HOME}/webapps/${APP_CONTEXT}"
    rm -f "${TOMCAT_HOME}/webapps/${APP_CONTEXT}.war"
    
    # Copy new WAR
    print_info "Deploying new WAR..."
    cp "${WAR_FILE}" "${TOMCAT_HOME}/webapps/${APP_CONTEXT}.war"
    
    # Start Tomcat
    print_info "Starting Tomcat with Java 25..."
    export JAVA_HOME=${JAVA_HOME_TOMCAT}
    export PATH=${JAVA_HOME}/bin:$PATH
    ${TOMCAT_HOME}/bin/startup.sh
    
    # Wait for startup
    print_info "Waiting for Tomcat to start..."
    sleep 10
    
    print_success "Deployment complete"
}

# Verify deployment
verify_deployment() {
    if [ "$DO_DEPLOY" = false ]; then
        return 0
    fi
    
    print_header "Verifying Deployment"
    
    # Check if Ansible playbook exists
    ANSIBLE_PLAYBOOK_VERIFY="${PROJECT_ROOT}/ansible/playbooks/verify_petclinic.yml"
    ANSIBLE_INVENTORY="${PROJECT_ROOT}/ansible/inventory/hosts.ini"
    
    if [ -f "${ANSIBLE_PLAYBOOK_VERIFY}" ] && command -v ansible-playbook &> /dev/null; then
        print_info "Using Ansible verification playbook..."
        cd "${PROJECT_ROOT}"
        ansible-playbook -i "${ANSIBLE_INVENTORY}" "${ANSIBLE_PLAYBOOK_VERIFY}" -v
        
        if [ $? -eq 0 ]; then
            print_success "All verification checks PASSED"
            
            # Display summary if available
            if [ -f "/home/pet-clinic/build/verification-summary.txt" ]; then
                echo ""
                cat /home/pet-clinic/build/verification-summary.txt
            fi
        else
            print_error "Verification checks FAILED"
            return 1
        fi
    else
        print_warning "Ansible verification playbook not available, using manual verification..."
        verify_manually
    fi
}

# Manual verification (fallback)
verify_manually() {
    APP_URL="http://localhost:${TOMCAT_PORT}/${APP_CONTEXT}"
    
    print_info "Waiting for application to be ready..."
    sleep 10
    
    FAILED=0
    
    # Test 1: Home page
    print_info "Testing home page..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/ || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Home page OK (HTTP $HTTP_CODE)"
    else
        print_error "Home page FAILED (HTTP $HTTP_CODE)"
        FAILED=$((FAILED + 1))
    fi
    
    # Test 2: Vets page
    print_info "Testing vets page..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/vets.html || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Vets page OK (HTTP $HTTP_CODE)"
    else
        print_error "Vets page FAILED (HTTP $HTTP_CODE)"
        FAILED=$((FAILED + 1))
    fi
    
    # Test 3: Find owners page
    print_info "Testing find owners page..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/owners/find || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Find owners page OK (HTTP $HTTP_CODE)"
    else
        print_error "Find owners page FAILED (HTTP $HTTP_CODE)"
        FAILED=$((FAILED + 1))
    fi
    
    # Test 4: Check Tomcat process
    print_info "Checking Tomcat process..."
    if ps aux | grep -v grep | grep -q "catalina"; then
        print_success "Tomcat process is running"
    else
        print_error "Tomcat process not found"
        FAILED=$((FAILED + 1))
    fi
    
    # Test 5: Check Tomcat port
    print_info "Checking Tomcat port..."
    if netstat -tuln 2>/dev/null | grep -q ":${TOMCAT_PORT}" || ss -tuln 2>/dev/null | grep -q ":${TOMCAT_PORT}"; then
        print_success "Tomcat listening on port ${TOMCAT_PORT}"
    else
        print_error "Tomcat not listening on port ${TOMCAT_PORT}"
        FAILED=$((FAILED + 1))
    fi
    
    echo ""
    if [ $FAILED -eq 0 ]; then
        print_success "All verification checks PASSED"
    else
        print_error "$FAILED verification check(s) FAILED"
        return 1
    fi
}

# Main execution
main() {
    local START_TIME=$(date +%s)
    
    print_header "PetClinic Build and Deploy"
    
    print_info "Configuration:"
    print_info "  Project Root: ${PROJECT_ROOT}"
    print_info "  PetClinic Source: ${PETCLINIC_SRC}"
    print_info "  Build Directory: ${BUILD_DIR}"
    print_info "  Skip Tests: ${SKIP_TESTS}"
    print_info "  Deploy: ${DO_DEPLOY}"
    print_info "  Clean Build: ${DO_CLEAN}"
    echo ""
    
    # Execute stages
    check_prerequisites
    build_application
    deploy_application
    verify_deployment
    
    # Summary
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    
    print_header "Build and Deploy Complete"
    
    echo ""
    print_success "✓ Build and deployment completed successfully!"
    echo ""
    print_info "Duration: ${DURATION} seconds"
    echo ""
    print_info "Access URLs:"
    print_info "  Application: http://localhost:${TOMCAT_PORT}/${APP_CONTEXT}"
    print_info "  Vets: http://localhost:${TOMCAT_PORT}/${APP_CONTEXT}/vets.html"
    print_info "  Find Owners: http://localhost:${TOMCAT_PORT}/${APP_CONTEXT}/owners/find"
    print_info "  Tomcat Manager: http://localhost:${TOMCAT_PORT}/manager"
    echo ""
    print_info "Logs:"
    print_info "  Tomcat: tail -f ${TOMCAT_HOME}/logs/catalina.out"
    echo ""
}

# Run main function
main "$@"

