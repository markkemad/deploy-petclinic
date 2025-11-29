#!/usr/bin/env groovy

/**
 * =============================================================================
 * PetClinic CI/CD Pipeline
 * =============================================================================
 * Description: Automated build and deployment pipeline for Spring PetClinic
 * Author: DevOps Team
 * Version: 1.0
 * 
 * Pipeline Stages:
 *   1. Checkout      - Get source code from repository
 *   2. Environment   - Setup build environment (Java 25)
 *   3. Build         - Compile and package WAR file
 *   4. Test          - Run unit tests (optional)
 *   5. Deploy        - Deploy to Tomcat via Ansible
 *   6. Verify        - Run sanity checks
 *   7. Monitoring    - Verify monitoring is active
 *   8. Notify        - Send notifications
 * 
 * Prerequisites:
 *   - Jenkins with Java 21 runtime
 *   - Java 25 installed at /home/pet-clinic/java/jdk25 (Maven builds & Tomcat)
 *   - Java 21 installed at /home/pet-clinic/java/jdk21 (Jenkins runtime)
 *   - Tomcat 10 running on port 9090 with Java 25
 *   - Ansible installed
 *   - pet-clinic user with proper permissions
 * =============================================================================
 */

pipeline {
    agent any
    
    environment {
        // Java Configuration
        JAVA25_HOME = '/home/pet-clinic/java/jdk25'
        JAVA21_HOME = '/home/pet-clinic/java/jdk21'
        
        // Build Configuration
        // Note: WORKSPACE is a Jenkins built-in variable (workspace root path)
        PETCLINIC_SRC = "${WORKSPACE}/spring-petclinic"
        BUILD_DIR = '/home/pet-clinic/build'
        WAR_FILE = "${BUILD_DIR}/petclinic.war"
        
        // Tomcat Configuration
        TOMCAT_HOME = '/home/pet-clinic/tomcat'
        TOMCAT_PORT = '9090'
        APP_CONTEXT = 'petclinic'
        APP_URL = "http://localhost:${TOMCAT_PORT}/${APP_CONTEXT}"
        
        // Ansible Configuration
        ANSIBLE_PLAYBOOK_DEPLOY = "${WORKSPACE}/ansible/playbooks/deploy_petclinic.yml"
        ANSIBLE_PLAYBOOK_VERIFY = "${WORKSPACE}/ansible/playbooks/verify_petclinic.yml"
        ANSIBLE_INVENTORY = "${WORKSPACE}/ansible/inventory/hosts.ini"
        
        // Build Options
        SKIP_TESTS = 'true'  // Set to 'false' to run tests
        MAVEN_OPTS = '-Xmx512m'
    }
    
    options {
        // Build options
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║               Stage 1: Checkout Source Code               ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                // Checkout is automatic when using Pipeline from SCM
                // This stage just validates the checkout
                sh '''
                    echo "✓ Workspace: ${WORKSPACE}"
                    echo "✓ Checking repository structure..."
                    
                    if [ -d "${PETCLINIC_SRC}" ]; then
                        echo "✓ PetClinic source found"
                    else
                        echo "✗ ERROR: PetClinic source not found!"
                        exit 1
                    fi
                    
                    if [ -f "${PETCLINIC_SRC}/pom.xml" ]; then
                        echo "✓ Maven POM file found"
                    else
                        echo "✗ ERROR: pom.xml not found!"
                        exit 1
                    fi
                    
                    if [ -f "${PETCLINIC_SRC}/mvnw" ]; then
                        echo "✓ Maven wrapper found"
                        chmod +x "${PETCLINIC_SRC}/mvnw"
                    else
                        echo "✗ ERROR: Maven wrapper not found!"
                        exit 1
                    fi
                    
                    echo "✓ Repository structure validated"
                '''
            }
        }
        
        stage('Environment Setup') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║            Stage 2: Environment Setup (Java 25)            ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    echo "Verifying Java installations..."
                    
                    # Check Java 25 (for Maven builds)
                    if [ -d "${JAVA25_HOME}" ]; then
                        echo "✓ Java 25 found at ${JAVA25_HOME}"
                        ${JAVA25_HOME}/bin/java -version
                    else
                        echo "✗ ERROR: Java 25 not found at ${JAVA25_HOME}"
                        exit 1
                    fi
                    
                    # Check Java 21 (for Tomcat runtime)
                    if [ -d "${JAVA21_HOME}" ]; then
                        echo "✓ Java 21 found at ${JAVA21_HOME}"
                        ${JAVA21_HOME}/bin/java -version
                    else
                        echo "✗ ERROR: Java 21 not found at ${JAVA21_HOME}"
                        exit 1
                    fi
                    
                    # Create build directory if it doesn't exist
                    mkdir -p ${BUILD_DIR}
                    echo "✓ Build directory ready: ${BUILD_DIR}"
                    
                    echo "✓ Environment setup complete"
                '''
            }
        }
        
        stage('Build') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║             Stage 3: Build PetClinic WAR File              ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    cd ${PETCLINIC_SRC}
                    
                    echo "Starting Maven build..."
                    echo "Build tool: Maven Wrapper (mvnw)"
                    echo "Java version: Java 25"
                    echo "Skip tests: ${SKIP_TESTS}"
                    
                    # Set Java 25 for the build
                    export JAVA_HOME=${JAVA25_HOME}
                    export PATH=${JAVA_HOME}/bin:$PATH
                    
                    # Verify Java version
                    echo "Using Java version:"
                    java -version
                    
                    # Clean previous builds
                    echo "Cleaning previous builds..."
                    ./mvnw clean
                    
                    # Build the WAR file
                    if [ "${SKIP_TESTS}" = "true" ]; then
                        echo "Building WAR (skipping tests)..."
                        ./mvnw package -DskipTests
                    else
                        echo "Building WAR (with tests)..."
                        ./mvnw package
                    fi
                    
                    # Check if WAR was created
                    if [ -f target/*.war ]; then
                        WAR_NAME=$(ls target/*.war)
                        echo "✓ Build successful: ${WAR_NAME}"
                        
                        # Copy to build directory
                        cp target/*.war ${WAR_FILE}
                        echo "✓ WAR copied to: ${WAR_FILE}"
                        
                        # Display WAR info
                        ls -lh ${WAR_FILE}
                        echo "✓ WAR size: $(du -h ${WAR_FILE} | cut -f1)"
                    else
                        echo "✗ ERROR: WAR file not created!"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Test') {
            when {
                expression { env.SKIP_TESTS == 'false' }
            }
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║                Stage 4: Run Unit Tests                     ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    cd ${PETCLINIC_SRC}
                    
                    export JAVA_HOME=${JAVA25_HOME}
                    export PATH=${JAVA_HOME}/bin:$PATH
                    
                    echo "Running unit tests..."
                    ./mvnw test
                    
                    echo "✓ Tests completed"
                '''
            }
            post {
                always {
                    // Publish test results if available
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║           Stage 5: Deploy to Tomcat via Ansible            ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    echo "Deployment Configuration:"
                    echo "  Playbook: ${ANSIBLE_PLAYBOOK_DEPLOY}"
                    echo "  Inventory: ${ANSIBLE_INVENTORY}"
                    echo "  WAR file: ${WAR_FILE}"
                    echo "  Tomcat: ${TOMCAT_HOME}"
                    echo "  Port: ${TOMCAT_PORT}"
                    echo "  Context: ${APP_CONTEXT}"
                    echo ""
                    
                    # Verify prerequisites
                    if [ ! -f "${WAR_FILE}" ]; then
                        echo "✗ ERROR: WAR file not found!"
                        exit 1
                    fi
                    
                    if [ ! -f "${ANSIBLE_PLAYBOOK_DEPLOY}" ]; then
                        echo "✗ ERROR: Ansible playbook not found!"
                        exit 1
                    fi
                    
                    # Run Ansible deployment
                    echo "Starting Ansible deployment..."
                    cd ${WORKSPACE}
                    
                    ansible-playbook \
                        -i ${ANSIBLE_INVENTORY} \
                        ${ANSIBLE_PLAYBOOK_DEPLOY} \
                        -v
                    
                    DEPLOY_RESULT=$?
                    
                    if [ $DEPLOY_RESULT -eq 0 ]; then
                        echo "✓ Deployment successful"
                    else
                        echo "✗ Deployment failed with exit code: $DEPLOY_RESULT"
                        exit $DEPLOY_RESULT
                    fi
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║            Stage 6: Verify Deployment & Sanity             ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    echo "Running verification and sanity checks via Ansible..."
                    echo "Playbook: ${ANSIBLE_PLAYBOOK_VERIFY}"
                    echo "Application URL: ${APP_URL}"
                    echo ""
                    
                    # Verify playbook exists
                    if [ ! -f "${ANSIBLE_PLAYBOOK_VERIFY}" ]; then
                        echo "✗ ERROR: Verification playbook not found!"
                        exit 1
                    fi
                    
                    # Run Ansible verification playbook
                    cd ${WORKSPACE}
                    
                    ansible-playbook \
                        -i ${ANSIBLE_INVENTORY} \
                        ${ANSIBLE_PLAYBOOK_VERIFY} \
                        -v
                    
                    VERIFY_RESULT=$?
                    
                    if [ $VERIFY_RESULT -eq 0 ]; then
                        echo ""
                        echo "✓ All verification checks PASSED"
                        
                        # Display verification summary if available
                        if [ -f "/home/pet-clinic/build/verification-summary.txt" ]; then
                            echo ""
                            echo "Verification Summary:"
                            cat /home/pet-clinic/build/verification-summary.txt
                        fi
                    else
                        echo ""
                        echo "✗ Verification failed with exit code: $VERIFY_RESULT"
                        exit $VERIFY_RESULT
                    fi
                '''
            }
        }
        
        stage('Monitoring') {
            steps {
                script {
                    echo '╔════════════════════════════════════════════════════════════╗'
                    echo '║             Stage 7: Verify Monitoring Status              ║'
                    echo '╚════════════════════════════════════════════════════════════╝'
                }
                
                sh '''
                    echo "Checking monitoring status..."
                    
                    # Check if monitoring scripts exist
                    MONITORING_DIR="/home/pet-clinic/monitoring"
                    
                    if [ -d "${MONITORING_DIR}" ]; then
                        echo "✓ Monitoring directory exists: ${MONITORING_DIR}"
                        
                        # Check monitoring scripts
                        if [ -f "${MONITORING_DIR}/monitor-all.sh" ]; then
                            echo "✓ Monitoring script found"
                            
                            # Run monitoring check
                            bash ${MONITORING_DIR}/monitor-all.sh || true
                        else
                            echo "⚠ Warning: Monitoring scripts not found"
                            echo "  Monitoring can be configured later"
                        fi
                    else
                        echo "⚠ Warning: Monitoring not configured"
                        echo "  Run ansible/playbooks/install-monitoring.yml to set up monitoring"
                    fi
                    
                    echo "✓ Monitoring check complete"
                '''
            }
        }
    }
    
    post {
        success {
            script {
                echo '╔════════════════════════════════════════════════════════════╗'
                echo '║                  ✓ PIPELINE SUCCESSFUL                     ║'
                echo '╚════════════════════════════════════════════════════════════╝'
                echo ''
                echo "Build Information:"
                echo "  Build Number: ${BUILD_NUMBER}"
                echo "  Build ID: ${BUILD_ID}"
                echo "  Build URL: ${BUILD_URL}"
                echo "  Workspace: ${WORKSPACE}"
                echo ''
                echo "Deployment Information:"
                echo "  Application: PetClinic"
                echo "  Version: 4.0.0-SNAPSHOT"
                echo "  Server: Tomcat 10"
                echo "  Runtime: Java 25"
                echo "  Port: ${TOMCAT_PORT}"
                echo "  Context: ${APP_CONTEXT}"
                echo ''
                echo "Access URLs:"
                echo "  Application: ${APP_URL}"
                echo "  Vets: ${APP_URL}/vets.html"
                echo "  Find Owners: ${APP_URL}/owners/find"
                echo "  Tomcat Manager: http://localhost:${TOMCAT_PORT}/manager"
                echo ''
                echo '════════════════════════════════════════════════════════════'
            }
            
            // Send success notification (configure email, Slack, etc.)
            // emailext(
            //     subject: "✓ PetClinic Pipeline Success - Build #${BUILD_NUMBER}",
            //     body: "The PetClinic deployment pipeline completed successfully.\n\nAccess at: ${APP_URL}",
            //     to: "devops-team@example.com"
            // )
        }
        
        failure {
            script {
                echo '╔════════════════════════════════════════════════════════════╗'
                echo '║                    ✗ PIPELINE FAILED                       ║'
                echo '╚════════════════════════════════════════════════════════════╝'
                echo ''
                echo "Build Information:"
                echo "  Build Number: ${BUILD_NUMBER}"
                echo "  Build ID: ${BUILD_ID}"
                echo "  Build URL: ${BUILD_URL}"
                echo ''
                echo "Troubleshooting:"
                echo "  1. Check Jenkins console output: ${BUILD_URL}console"
                echo "  2. Check Tomcat logs: ${TOMCAT_HOME}/logs/catalina.out"
                echo "  3. Check application logs: ${TOMCAT_HOME}/logs/"
                echo "  4. Verify Java installations"
                echo "  5. Verify Tomcat is running: ps aux | grep catalina"
                echo ''
                echo '════════════════════════════════════════════════════════════'
            }
            
            // Send failure notification
            // emailext(
            //     subject: "✗ PetClinic Pipeline Failed - Build #${BUILD_NUMBER}",
            //     body: "The PetClinic deployment pipeline failed.\n\nCheck logs at: ${BUILD_URL}console",
            //     to: "devops-team@example.com"
            // )
        }
        
        unstable {
            echo '⚠ Pipeline completed with warnings'
        }
        
        always {
            // Cleanup temporary files if any
            sh '''
                echo "Cleaning up temporary files..."
                # Add cleanup commands here if needed
                echo "✓ Cleanup complete"
            '''
        }
    }
}

