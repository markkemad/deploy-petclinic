# Jenkins Pipeline Setup Guide

## Overview
This guide provides step-by-step instructions for setting up and configuring the Jenkins CI/CD pipeline for the PetClinic application.

## Prerequisites

Before setting up the Jenkins pipeline, ensure the following are in place:

- [x] Jenkins installed and running at `http://localhost:8080`
- [x] Java 21 installed at `/home/pet-clinic/java/jdk21` (Jenkins runtime)
- [x] Java 25 installed at `/home/pet-clinic/java/jdk25` (Maven builds)
- [x] Tomcat 10 installed and configured at `/home/pet-clinic/tomcat`
- [x] Ansible installed on the system
- [x] Git repository cloned to accessible location
- [x] User `pet-clinic` has proper permissions

## Step 1: Initial Jenkins Configuration

### 1.1 Access Jenkins
```bash
# Start Jenkins if not running
bash /home/pet-clinic/jenkins/start-jenkins.sh

# Get initial admin password
cat /home/pet-clinic/jenkins/secrets/initialAdminPassword
```

Access Jenkins at: `http://localhost:8080`

### 1.2 Install Required Plugins

Navigate to **Manage Jenkins** → **Plugin Manager** → **Available Plugins**

Install the following plugins:

#### Essential Plugins:
- [x] **Pipeline** (Declarative Pipeline support)
- [x] **Git Plugin** (SCM integration)
- [x] **Workspace Cleanup Plugin** (Clean workspace between builds)
- [x] **Timestamper** (Add timestamps to console output)
- [x] **AnsiColor** (Colored console output)

#### Optional but Recommended:
- [ ] **Blue Ocean** (Modern UI for pipelines)
- [ ] **Email Extension Plugin** (Email notifications)
- [ ] **Slack Notification** (Slack integration)
- [ ] **Build Timeout** (Timeout protection)
- [ ] **Dashboard View** (Custom dashboards)

After installation, restart Jenkins:
```bash
bash /home/pet-clinic/jenkins/stop-jenkins.sh
bash /home/pet-clinic/jenkins/start-jenkins.sh
```

## Step 2: Create Pipeline Job

### 2.1 Create New Pipeline
1. Click **New Item** in Jenkins dashboard
2. Enter name: `PetClinic-Pipeline`
3. Select **Pipeline** as job type
4. Click **OK**

### 2.2 Configure Pipeline

#### General Settings
- [x] **Description**: `Automated CI/CD pipeline for Spring PetClinic application`
- [x] **Discard old builds**: Keep last 10 builds
- [x] **Do not allow concurrent builds** (checked)

#### Build Triggers (Choose one or more)
- [ ] **GitHub hook trigger** (for automated builds on push)
- [ ] **Poll SCM**: `H/15 * * * *` (check every 15 minutes)
- [ ] **Build periodically**: `H 2 * * *` (nightly builds at 2 AM)
- [x] **Build manually** (no automatic trigger)

#### Pipeline Configuration

**Pipeline Definition**: Select **Pipeline script from SCM**

**SCM**: Select **Git**

**Repository Configuration**:
- **Repository URL**: Enter your Git repository URL
  - Example: `https://github.com/YOUR_USERNAME/deploy-petclinic.git`
  - Or local: `file:///home/pet-clinic/deploy-petclinic`

**Credentials** (if repository is private):
- Click **Add** → **Jenkins**
- Kind: **Username with password** or **SSH Username with private key**
- Add your Git credentials

**Branches to build**:
- Branch Specifier: `*/main` (or `*/master` depending on your default branch)

**Script Path**: `Jenkinsfile`

**Lightweight checkout**: Unchecked (need full workspace)

Click **Save**

## Step 3: Configure System Environment

### 3.1 Global Environment Variables

Navigate to **Manage Jenkins** → **Configure System** → **Global properties**

Check **Environment variables** and add:

| Name | Value |
|------|-------|
| `JAVA21_HOME` | `/home/pet-clinic/java/jdk21` |
| `JAVA25_HOME` | `/home/pet-clinic/java/jdk25` |
| `TOMCAT_HOME` | `/home/pet-clinic/tomcat` |

### 3.2 Tool Configuration

Navigate to **Manage Jenkins** → **Global Tool Configuration**

#### JDK Configuration (Optional)
If you want to manage Java via Jenkins:
- Click **Add JDK**
- Name: `Java 25`
- Uncheck **Install automatically**
- JAVA_HOME: `/home/pet-clinic/java/jdk25`

Repeat for Java 21:
- Name: `Java 21`
- JAVA_HOME: `/home/pet-clinic/java/jdk21`

## Step 4: Test the Pipeline

### 4.1 First Build
1. Navigate to your pipeline job: **PetClinic-Pipeline**
2. Click **Build Now**
3. Watch the build progress in **Build History**
4. Click on the build number (e.g., #1)
5. Click **Console Output** to see detailed logs

### 4.2 Expected Build Stages

The pipeline should execute the following stages:

1. ✓ **Checkout** - Source code retrieval
2. ✓ **Environment Setup** - Java verification
3. ✓ **Build** - Maven WAR compilation
4. ⊘ **Test** - Unit tests (skipped by default)
5. ✓ **Archive Artifacts** - WAR archival
6. ✓ **Deploy** - Ansible deployment to Tomcat
7. ✓ **Verify Deployment** - Sanity checks
8. ✓ **Monitoring** - Status verification

### 4.3 Verify Deployment

After successful build:

```bash
# Check application is running
curl http://localhost:9090/petclinic/

# Check specific endpoints
curl http://localhost:9090/petclinic/vets.html
curl http://localhost:9090/petclinic/owners/find

# Check Tomcat logs
tail -f /home/pet-clinic/tomcat/logs/catalina.out
```

Access in browser: `http://localhost:9090/petclinic`

## Step 5: Pipeline Customization

### 5.1 Enable Unit Tests

Edit the pipeline environment variables in the Jenkinsfile:

```groovy
environment {
    SKIP_TESTS = 'false'  // Change from 'true' to 'false'
}
```

Or configure as a parameter:

```groovy
parameters {
    booleanParam(name: 'SKIP_TESTS', defaultValue: true, description: 'Skip unit tests')
}
```

### 5.2 Add Build Parameters

Add parameters to make the pipeline more flexible:

```groovy
parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Deployment environment')
    booleanParam(name: 'SKIP_TESTS', defaultValue: true, description: 'Skip unit tests')
    booleanParam(name: 'DEPLOY', defaultValue: true, description: 'Deploy after build')
    string(name: 'TOMCAT_PORT', defaultValue: '9090', description: 'Tomcat port')
}
```

### 5.3 Configure Notifications

#### Email Notifications

Install **Email Extension Plugin**, then configure in **Manage Jenkins** → **Configure System**:

**Extended E-mail Notification**:
- SMTP server: `smtp.gmail.com`
- SMTP port: `587`
- Use SSL: Checked
- Credentials: Add Gmail credentials

Uncomment the email sections in the Jenkinsfile `post` blocks.

#### Slack Notifications

Install **Slack Notification Plugin**, then:

1. Create Slack incoming webhook
2. Add webhook URL in **Manage Jenkins** → **Configure System** → **Slack**
3. Add Slack notifications to Jenkinsfile:

```groovy
post {
    success {
        slackSend(color: 'good', message: "✓ Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
    }
    failure {
        slackSend(color: 'danger', message: "✗ Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
    }
}
```

## Step 6: Advanced Configuration

### 6.1 Multi-Branch Pipeline

For multiple branches (feature branches, develop, main):

1. Create **New Item** → **Multibranch Pipeline**
2. Add Git source
3. Jenkins will automatically discover and build all branches with Jenkinsfile

### 6.2 Pipeline Triggers via GitHub Webhook

If using GitHub:

1. Go to your GitHub repository → **Settings** → **Webhooks**
2. Click **Add webhook**
3. Payload URL: `http://YOUR_JENKINS_URL:8080/github-webhook/`
4. Content type: `application/json`
5. Select: **Just the push event**
6. Active: Checked
7. Click **Add webhook**

In Jenkins job configuration:
- Check **GitHub hook trigger for GITScm polling**

### 6.3 Scheduled Builds

Add cron-style scheduling in pipeline:

```groovy
triggers {
    cron('H 2 * * *')  // Daily at 2 AM
    pollSCM('H/15 * * * *')  // Poll SCM every 15 minutes
}
```

### 6.4 Pipeline Visualization (Blue Ocean)

Install **Blue Ocean** plugin for modern UI:

```bash
# Access Blue Ocean interface
http://localhost:8080/blue/organizations/jenkins/PetClinic-Pipeline/
```

## Step 7: Troubleshooting

### Common Issues and Solutions

#### Issue 1: Permission Denied

**Error**: `Permission denied` when accessing workspace or running scripts

**Solution**:
```bash
# Ensure pet-clinic user owns the workspace
sudo chown -R pet-clinic:pet-clinic /home/pet-clinic/.jenkins/workspace

# Ensure scripts are executable
chmod +x /home/pet-clinic/deploy-petclinic/spring-petclinic/mvnw
```

#### Issue 2: Java Version Mismatch

**Error**: `Unsupported class file major version 69`

**Solution**: Verify Java 25 is being used for Maven builds:
```bash
export JAVA_HOME=/home/pet-clinic/java/jdk25
export PATH=$JAVA_HOME/bin:$PATH
java -version
```

#### Issue 3: Ansible Not Found

**Error**: `ansible-playbook: command not found`

**Solution**:
```bash
# Check if Ansible is installed
which ansible-playbook

# If not, install Ansible
sudo bash scripts/install-ansible.sh
```

#### Issue 4: WAR Not Deploying

**Error**: WAR file exists but application returns 404

**Solution**:
```bash
# Check Tomcat logs
tail -f /home/pet-clinic/tomcat/logs/catalina.out

# Verify ServletInitializer exists
ls spring-petclinic/src/main/java/org/springframework/samples/petclinic/ServletInitializer.java

# Verify packaging is set to 'war' in pom.xml
grep '<packaging>' spring-petclinic/pom.xml
```

#### Issue 5: Port Already in Use

**Error**: `Address already in use: bind`

**Solution**:
```bash
# Check what's using the port
sudo netstat -tulpn | grep 9090

# Or with ss
sudo ss -tulpn | grep 9090

# Stop conflicting process or change Tomcat port
```

#### Issue 6: Out of Memory

**Error**: `java.lang.OutOfMemoryError: Java heap space`

**Solution**: Increase Maven memory in Jenkinsfile:
```groovy
environment {
    MAVEN_OPTS = '-Xmx1024m'  // Increase from 512m to 1024m
}
```

### Viewing Logs

```bash
# Jenkins logs
tail -f /home/pet-clinic/jenkins/jenkins.log

# Tomcat logs
tail -f /home/pet-clinic/tomcat/logs/catalina.out

# Application logs
tail -f /home/pet-clinic/tomcat/logs/localhost.*.log

# Build artifacts location
ls -lh /home/pet-clinic/.jenkins/workspace/PetClinic-Pipeline/
```

## Step 8: Best Practices

### 8.1 Security

- [ ] Change default passwords (admin/123)
- [ ] Enable CSRF protection in Jenkins
- [ ] Use Jenkins credentials store for sensitive data
- [ ] Enable authorization (Matrix-based security)
- [ ] Use HTTPS for Jenkins (if exposed to network)

### 8.2 Performance

- [ ] Set appropriate build retention policy
- [ ] Use workspace cleanup plugin
- [ ] Archive only necessary artifacts
- [ ] Enable build timeout
- [ ] Use Jenkins agents for distributed builds (optional)

### 8.3 Maintenance

- [ ] Regularly update Jenkins and plugins
- [ ] Backup Jenkins configuration (`$JENKINS_HOME`)
- [ ] Monitor disk space usage
- [ ] Review build history and trends
- [ ] Document custom configurations

## Quick Reference Commands

```bash
# Start Jenkins
bash /home/pet-clinic/jenkins/start-jenkins.sh

# Stop Jenkins
bash /home/pet-clinic/jenkins/stop-jenkins.sh

# Check Jenkins status
bash /home/pet-clinic/jenkins/status-jenkins.sh

# View Jenkins logs
tail -f /home/pet-clinic/jenkins/jenkins.log

# Restart Jenkins (from UI)
# Navigate to: http://localhost:8080/restart

# Reload configuration (from UI)
# Navigate to: http://localhost:8080/reload

# Manual build (from workspace)
cd /home/pet-clinic/deploy-petclinic/spring-petclinic
export JAVA_HOME=/home/pet-clinic/java/jdk25
./mvnw clean package -DskipTests

# Manual deployment
cd /home/pet-clinic/deploy-petclinic
ansible-playbook ansible/playbooks/deploy_petclinic.yml

# Check application
curl http://localhost:9090/petclinic/
```

## Useful URLs

- Jenkins Dashboard: `http://localhost:8080`
- Jenkins Blue Ocean: `http://localhost:8080/blue`
- Tomcat Manager: `http://localhost:9090/manager` (admin/123)
- PetClinic Application: `http://localhost:9090/petclinic`
- Jenkins REST API: `http://localhost:8080/api/`

## Next Steps

Once the pipeline is working:

1. ✓ Configure automated triggers (GitHub webhooks or polling)
2. ✓ Set up notifications (email or Slack)
3. ✓ Add code quality checks (SonarQube integration)
4. ✓ Implement deployment strategies (blue-green, canary)
5. ✓ Set up monitoring and alerting integration
6. ✓ Create additional pipelines for different environments
7. ✓ Document runbooks for common scenarios

## Support and Resources

- Jenkins Documentation: https://www.jenkins.io/doc/
- Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- Plugin Index: https://plugins.jenkins.io/
- Spring Boot on Tomcat: https://docs.spring.io/spring-boot/docs/current/reference/html/howto.html#howto.traditional-deployment

---

**Last Updated**: 2025-11-29  
**Version**: 1.0  
**Maintainer**: DevOps Team

