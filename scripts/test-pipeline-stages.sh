#!/bin/bash

################################################################################
# Pipeline Stage Testing Script
################################################################################
# Description: Test individual Jenkins pipeline stages locally before running
#              in Jenkins to identify and fix issues quickly
# Author: DevOps Team
# Version: 1.0
# Usage: bash scripts/test-pipeline-stages.sh [STAGE]
#
# Stages:
#   checkout       - Test repository checkout
#   environment    - Test environment setup
#   build          - Test Maven build
#   deploy         - Test deployment
#   verify         - Test verification
#   all            - Run all stages (default)
################################################################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PETCLINIC_SRC="${PROJECT_ROOT}/spring-petclinic"
BUILD_DIR="/home/pet-clinic/build"
JAVA25_HOME="/home/pet-clinic/java/jdk25"
JAVA21_HOME="/home/pet-clinic/java/jdk21"
TOMCAT_HOME="/home/pet-clinic/tomcat"

# Determine stage to test
STAGE="${1:-all}"

print_stage() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} Testing Stage: $1"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Test Checkout Stage
test_checkout() {
    print_stage "Checkout"
    
    print_info "Workspace: ${PROJECT_ROOT}"
    
    if [ -d "${PETCLINIC_SRC}" ]; then
        print_success "PetClinic source found"
    else
        print_error "PetClinic source not found!"
        return 1
    fi
    
    if [ -f "${PETCLINIC_SRC}/pom.xml" ]; then
        print_success "Maven POM file found"
    else
        print_error "pom.xml not found!"
        return 1
    fi
    
    if [ -f "${PETCLINIC_SRC}/mvnw" ]; then
        print_success "Maven wrapper found"
        chmod +x "${PETCLINIC_SRC}/mvnw"
    else
        print_error "Maven wrapper not found!"
        return 1
    fi
    
    print_success "Checkout stage OK"
}

# Test Environment Setup Stage
test_environment() {
    print_stage "Environment Setup"
    
    # Check Java 25
    if [ -d "${JAVA25_HOME}" ]; then
        print_success "Java 25 found at ${JAVA25_HOME}"
        echo ""
        ${JAVA25_HOME}/bin/java -version
        echo ""
    else
        print_error "Java 25 not found at ${JAVA25_HOME}"
        return 1
    fi
    
    # Check Java 21
    if [ -d "${JAVA21_HOME}" ]; then
        print_success "Java 21 found at ${JAVA21_HOME}"
        echo ""
        ${JAVA21_HOME}/bin/java -version
        echo ""
    else
        print_error "Java 21 not found at ${JAVA21_HOME}"
        return 1
    fi
    
    # Check build directory
    mkdir -p ${BUILD_DIR}
    if [ -d "${BUILD_DIR}" ]; then
        print_success "Build directory ready: ${BUILD_DIR}"
    else
        print_error "Cannot create build directory!"
        return 1
    fi
    
    print_success "Environment setup stage OK"
}

# Test Build Stage
test_build() {
    print_stage "Build"
    
    cd ${PETCLINIC_SRC}
    
    export JAVA_HOME=${JAVA25_HOME}
    export PATH=${JAVA_HOME}/bin:$PATH
    export MAVEN_OPTS="-Xmx512m"
    
    print_info "Starting Maven build..."
    print_info "Java version:"
    java -version
    echo ""
    
    print_info "Cleaning..."
    ./mvnw clean
    
    print_info "Building (skipping tests)..."
    ./mvnw package -DskipTests
    
    if [ -f target/*.war ]; then
        WAR_NAME=$(ls target/*.war)
        print_success "Build successful: ${WAR_NAME}"
        
        cp target/*.war ${BUILD_DIR}/petclinic.war
        print_success "WAR copied to: ${BUILD_DIR}/petclinic.war"
        
        WAR_SIZE=$(du -h ${BUILD_DIR}/petclinic.war | cut -f1)
        print_info "WAR size: ${WAR_SIZE}"
    else
        print_error "WAR file not created!"
        return 1
    fi
    
    print_success "Build stage OK"
}

# Test Deploy Stage
test_deploy() {
    print_stage "Deploy"
    
    ANSIBLE_PLAYBOOK="${PROJECT_ROOT}/ansible/playbooks/deploy_petclinic.yml"
    ANSIBLE_INVENTORY="${PROJECT_ROOT}/ansible/inventory/hosts.ini"
    
    if [ ! -f "${BUILD_DIR}/petclinic.war" ]; then
        print_error "WAR file not found! Run build stage first."
        return 1
    fi
    
    if [ ! -f "${ANSIBLE_PLAYBOOK}" ]; then
        print_error "Ansible playbook not found!"
        return 1
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible not installed!"
        return 1
    fi
    
    print_info "Running Ansible deployment..."
    cd ${PROJECT_ROOT}
    ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_PLAYBOOK} -v
    
    print_success "Deploy stage OK"
}

# Test Verify Stage
test_verify() {
    print_stage "Verify Deployment"
    
    ANSIBLE_PLAYBOOK="${PROJECT_ROOT}/ansible/playbooks/verify_petclinic.yml"
    ANSIBLE_INVENTORY="${PROJECT_ROOT}/ansible/inventory/hosts.ini"
    
    if [ ! -f "${ANSIBLE_PLAYBOOK}" ]; then
        print_error "Verification playbook not found!"
        return 1
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible not installed!"
        return 1
    fi
    
    print_info "Running Ansible verification playbook..."
    cd ${PROJECT_ROOT}
    ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_PLAYBOOK} -v
    
    if [ $? -eq 0 ]; then
        print_success "Verify stage OK"
        
        # Display summary if available
        if [ -f "/home/pet-clinic/build/verification-summary.txt" ]; then
            echo ""
            print_info "Verification Summary:"
            cat /home/pet-clinic/build/verification-summary.txt
        fi
    else
        print_error "Verification failed"
        return 1
    fi
}

# Main execution
case $STAGE in
    checkout)
        test_checkout
        ;;
    environment)
        test_environment
        ;;
    build)
        test_build
        ;;
    deploy)
        test_deploy
        ;;
    verify)
        test_verify
        ;;
    all)
        test_checkout && \
        test_environment && \
        test_build && \
        test_deploy && \
        test_verify
        
        echo ""
        print_success "✓ All pipeline stages tested successfully!"
        echo ""
        print_info "The pipeline is ready to be run in Jenkins."
        ;;
    *)
        echo -e "${RED}Unknown stage: $STAGE${NC}"
        echo ""
        echo "Available stages:"
        echo "  checkout"
        echo "  environment"
        echo "  build"
        echo "  deploy"
        echo "  verify"
        echo "  all (default)"
        exit 1
        ;;
esac

