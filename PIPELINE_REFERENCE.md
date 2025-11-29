# PetClinic CI/CD Pipeline - Quick Reference

## 📋 Quick Commands

### Jenkins Operations
```bash
# Start Jenkins
bash /home/pet-clinic/jenkins/start-jenkins.sh

# Stop Jenkins
bash /home/pet-clinic/jenkins/stop-jenkins.sh

# Check Jenkins status
bash /home/pet-clinic/jenkins/status-jenkins.sh

# View Jenkins logs
tail -f /home/pet-clinic/jenkins/jenkins.log

# Get initial admin password
cat /home/pet-clinic/jenkins/secrets/initialAdminPassword
```

### Manual Build & Deploy
```bash
# Full build and deploy
bash scripts/build-and-deploy.sh

# Build only (no deploy)
bash scripts/build-and-deploy.sh --no-deploy

# Build with tests
bash scripts/build-and-deploy.sh --run-tests

# Clean build
bash scripts/build-and-deploy.sh --clean

# Get help
bash scripts/build-and-deploy.sh --help
```

### Test Pipeline Stages Locally
```bash
# Test all stages
bash scripts/test-pipeline-stages.sh all

# Test individual stages
bash scripts/test-pipeline-stages.sh checkout
bash scripts/test-pipeline-stages.sh environment
bash scripts/test-pipeline-stages.sh build
bash scripts/test-pipeline-stages.sh deploy
bash scripts/test-pipeline-stages.sh verify
```

### Ansible Deployment
```bash
# Deploy using Ansible
cd /home/pet-clinic/deploy-petclinic
ansible-playbook ansible/playbooks/deploy_petclinic.yml

# Deploy with verbose output
ansible-playbook ansible/playbooks/deploy_petclinic.yml -v
ansible-playbook ansible/playbooks/deploy_petclinic.yml -vv
ansible-playbook ansible/playbooks/deploy_petclinic.yml -vvv
```

### Direct Maven Build
```bash
cd /home/pet-clinic/deploy-petclinic/spring-petclinic

# Set Java 25 for build
export JAVA_HOME=/home/pet-clinic/java/jdk25
export PATH=$JAVA_HOME/bin:$PATH

# Build (skip tests)
./mvnw clean package -DskipTests

# Build (with tests)
./mvnw clean package

# Run tests only
./mvnw test
```

### Tomcat Operations
```bash
# Start Tomcat
export JAVA_HOME=/home/pet-clinic/java/jdk25
export PATH=$JAVA_HOME/bin:$PATH
/home/pet-clinic/tomcat/bin/startup.sh

# Stop Tomcat
/home/pet-clinic/tomcat/bin/shutdown.sh

# View Tomcat logs
tail -f /home/pet-clinic/tomcat/logs/catalina.out

# Check Tomcat status
ps aux | grep catalina
netstat -tuln | grep 9090
```

### Application Testing
```bash
# Test application endpoints
curl http://localhost:9090/petclinic/
curl http://localhost:9090/petclinic/vets.html
curl http://localhost:9090/petclinic/owners/find

# Check HTTP status codes
curl -I http://localhost:9090/petclinic/
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/petclinic/
```

## 🏗️ Pipeline Stages

| Stage | Description | Duration | Dependencies |
|-------|-------------|----------|--------------|
| 1. Checkout | Clone source code from repository | ~10s | Git repository |
| 2. Environment Setup | Verify Java 21 & 25 installations | ~5s | Java installations |
| 3. Build | Compile and package WAR file | ~2-5min | Java 25, Maven |
| 4. Test | Run unit tests (optional) | ~1-3min | Build stage |
| 5. Archive Artifacts | Archive WAR file in Jenkins | ~5s | Build stage |
| 6. Deploy | Deploy to Tomcat via Ansible | ~30s | Ansible, Tomcat |
| 7. Verify Deployment | Run sanity checks | ~30s | Deploy stage |
| 8. Monitoring | Verify monitoring status | ~10s | Monitoring scripts |

**Total Duration**: ~5-10 minutes (depending on build and tests)

## 🔧 Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `Jenkinsfile` | Main pipeline definition | Root directory |
| `pom.xml` | Maven build configuration | `spring-petclinic/` |
| `deploy_petclinic.yml` | Ansible deployment playbook | `ansible/playbooks/` |
| `hosts.ini` | Ansible inventory | `ansible/inventory/` |

## 🌐 URLs and Ports

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8080 | See initialAdminPassword |
| PetClinic | http://localhost:9090/petclinic | N/A |
| Tomcat Manager | http://localhost:9090/manager | admin / 123 |
| Tomcat Host Manager | http://localhost:9090/host-manager | admin / 123 |

## 📊 Environment Variables

### Jenkins Pipeline Variables
```groovy
JAVA25_HOME = '/home/pet-clinic/java/jdk25'
JAVA21_HOME = '/home/pet-clinic/java/jdk21'
PETCLINIC_SRC = '${WORKSPACE}/spring-petclinic'
BUILD_DIR = '/home/pet-clinic/build'
WAR_FILE = '${BUILD_DIR}/petclinic.war'
TOMCAT_HOME = '/home/pet-clinic/tomcat'
TOMCAT_PORT = '9090'
APP_CONTEXT = 'petclinic'
SKIP_TESTS = 'true'
```

### Shell Environment
```bash
export JAVA_HOME=/home/pet-clinic/java/jdk25
export PATH=$JAVA_HOME/bin:$PATH
export MAVEN_OPTS='-Xmx512m'
export CATALINA_HOME=/home/pet-clinic/tomcat
```

## 🐛 Troubleshooting

### Pipeline Fails at Build Stage

**Symptom**: Maven build fails with compilation errors

**Solutions**:
```bash
# Verify Java 25 is installed
ls -la /home/pet-clinic/java/jdk25

# Check Java version
/home/pet-clinic/java/jdk25/bin/java -version

# Test build manually
cd spring-petclinic
export JAVA_HOME=/home/pet-clinic/java/jdk25
./mvnw clean package -DskipTests
```

### Pipeline Fails at Deploy Stage

**Symptom**: Ansible deployment fails

**Solutions**:
```bash
# Check if WAR file exists
ls -lh /home/pet-clinic/build/petclinic.war

# Check Tomcat is installed
ls -la /home/pet-clinic/tomcat/bin/catalina.sh

# Test Ansible playbook manually
cd /home/pet-clinic/deploy-petclinic
ansible-playbook ansible/playbooks/deploy_petclinic.yml -vv

# Check Tomcat logs
tail -100 /home/pet-clinic/tomcat/logs/catalina.out
```

### Pipeline Fails at Verify Stage

**Symptom**: Sanity checks fail, HTTP 404 or 500 errors

**Solutions**:
```bash
# Check if Tomcat is running
ps aux | grep catalina

# Check if port is open
netstat -tuln | grep 9090

# Check application logs
tail -100 /home/pet-clinic/tomcat/logs/catalina.out
tail -100 /home/pet-clinic/tomcat/logs/localhost.*.log

# Check if WAR was deployed
ls -la /home/pet-clinic/tomcat/webapps/petclinic/
ls -la /home/pet-clinic/tomcat/webapps/petclinic.war

# Test deployment manually
curl -v http://localhost:9090/petclinic/
```

### Out of Memory Errors

**Symptom**: `java.lang.OutOfMemoryError`

**Solutions**:
```groovy
// Increase memory in Jenkinsfile
environment {
    MAVEN_OPTS = '-Xmx1024m'  // Increase from 512m
}
```

### Permission Denied Errors

**Symptom**: Cannot write to workspace or build directory

**Solutions**:
```bash
# Fix ownership
sudo chown -R pet-clinic:pet-clinic /home/pet-clinic/.jenkins/workspace
sudo chown -R pet-clinic:pet-clinic /home/pet-clinic/build

# Fix permissions
chmod +x /home/pet-clinic/deploy-petclinic/spring-petclinic/mvnw
```

## 📈 Build Metrics

### Typical Build Times
- **Fast build** (skip tests): ~3 minutes
- **Full build** (with tests): ~5-7 minutes
- **Clean build** (with tests): ~6-8 minutes

### Artifact Sizes
- **WAR file**: ~40-50 MB
- **Jenkins workspace**: ~100-200 MB

### Resource Usage
- **Maven build**: ~512 MB RAM
- **Tomcat runtime**: ~256-512 MB RAM
- **Jenkins**: ~512 MB RAM

## 🔄 Common Workflows

### Making Code Changes
```bash
# 1. Make changes to source code
vim spring-petclinic/src/main/java/...

# 2. Test locally
bash scripts/build-and-deploy.sh

# 3. Commit and push
git add .
git commit -m "Your changes"
git push origin main

# 4. Build in Jenkins (automatic or manual)
# Go to Jenkins → PetClinic-Pipeline → Build Now
```

### Rolling Back Deployment
```bash
# 1. Stop Tomcat
/home/pet-clinic/tomcat/bin/shutdown.sh

# 2. Remove current deployment
rm -rf /home/pet-clinic/tomcat/webapps/petclinic*

# 3. Deploy previous version
cp /home/pet-clinic/build/petclinic-backup.war \
   /home/pet-clinic/tomcat/webapps/petclinic.war

# 4. Start Tomcat
export JAVA_HOME=/home/pet-clinic/java/jdk25
/home/pet-clinic/tomcat/bin/startup.sh
```

### Updating Configuration
```bash
# Update Tomcat port
vim /home/pet-clinic/tomcat/conf/server.xml

# Update application properties
vim spring-petclinic/src/main/resources/application.properties

# Rebuild and redeploy
bash scripts/build-and-deploy.sh --clean
```

## 📝 Pre-flight Checklist

Before running the pipeline, verify:

- [ ] Jenkins is running (`ps aux | grep jenkins`)
- [ ] Java 21 is installed at `/home/pet-clinic/java/jdk21`
- [ ] Java 25 is installed at `/home/pet-clinic/java/jdk25`
- [ ] Tomcat 10 is installed at `/home/pet-clinic/tomcat`
- [ ] Ansible is installed (`which ansible-playbook`)
- [ ] Repository is cloned and up-to-date
- [ ] Build directory exists (`/home/pet-clinic/build`)
- [ ] Ports 8080 (Jenkins) and 9090 (Tomcat) are available
- [ ] User `pet-clinic` has proper permissions

## 🎯 Success Criteria

A successful pipeline execution should:

- ✅ Complete all 8 stages without errors
- ✅ Generate WAR file (~40-50 MB)
- ✅ Deploy to Tomcat successfully
- ✅ Pass all 5 sanity checks (home, vets, owners, process, port)
- ✅ Complete in under 10 minutes
- ✅ Application accessible at http://localhost:9090/petclinic

## 📞 Support

For issues or questions:

1. Check Jenkins console output
2. Review Tomcat logs (`/home/pet-clinic/tomcat/logs/`)
3. Review application logs
4. Check this reference guide
5. Review `JENKINS_SETUP.md` for detailed setup
6. Check project documentation in `docs/`

## 🔗 Related Files

- `JENKINS_SETUP.md` - Detailed Jenkins configuration guide
- `Jenkinsfile` - Pipeline definition
- `scripts/build-and-deploy.sh` - Manual build script
- `scripts/test-pipeline-stages.sh` - Pipeline testing script
- `ansible/playbooks/deploy_petclinic.yml` - Deployment playbook

---

**Last Updated**: 2025-11-29  
**Version**: 1.0  
**Pipeline Version**: 1.0

