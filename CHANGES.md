# Jenkins Pipeline - Recent Changes

## Summary of Changes

### Date: 2025-11-29

---

## 1. Removed Archive Artifacts Stage

**Rationale**: Archive stage was not needed as the WAR file is stored in `/home/pet-clinic/build/`

**Changes**:
- ❌ Removed `Archive Artifacts` stage from Jenkinsfile
- ✅ Updated stage numbering (7 stages instead of 8)
- ✅ Removed `artifactNumToKeepStr` from build discarder options

**New Pipeline Stages**:
1. Checkout
2. Environment Setup
3. Build
4. Test (optional)
5. Deploy
6. Verify Deployment
7. Monitoring

---

## 2. Fixed WORKSPACE Variable Declaration

**Issue**: WORKSPACE variable was used but not declared

**Resolution**: 
- Added comment explaining that `WORKSPACE` is a Jenkins built-in variable
- No declaration needed - Jenkins provides this automatically
- Contains the absolute path to the workspace root directory

**Example**:
```groovy
environment {
    // Note: WORKSPACE is a Jenkins built-in variable (workspace root path)
    PETCLINIC_SRC = "${WORKSPACE}/spring-petclinic"
    ANSIBLE_PLAYBOOK_DEPLOY = "${WORKSPACE}/ansible/playbooks/deploy_petclinic.yml"
}
```

---

## 3. Created Separate Verification Playbook

**Rationale**: Better separation of concerns - deploy vs verify

**New File**: `ansible/playbooks/verify_petclinic.yml`

**Features**:
- ✅ Tests 3 application endpoints (home, vets, find owners)
- ✅ Verifies Tomcat process is running
- ✅ Checks port 9090 is listening
- ✅ Creates verification summary report
- ✅ Provides detailed output with visual formatting
- ✅ Retry logic for endpoint tests (3 retries, 5s delay)

**Endpoints Tested**:
1. `http://localhost:9090/petclinic/` - Home page
2. `http://localhost:9090/petclinic/vets.html` - Vets page
3. `http://localhost:9090/petclinic/owners/find` - Find owners page

**Outputs**:
- Console output with detailed test results
- Summary file: `/home/pet-clinic/build/verification-summary.txt`

---

## 4. Updated Jenkinsfile to Use Verification Playbook

**Changes**:
- ✅ Added `ANSIBLE_PLAYBOOK_VERIFY` environment variable
- ✅ Replaced shell script verification with Ansible playbook call
- ✅ Cleaner, more maintainable code
- ✅ Consistent with other pipeline stages (all use Ansible)
- ✅ Better error handling and reporting

**Before** (Shell script):
```bash
# Test 1: Home page
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${APP_URL}/)
if [ "$HTTP_CODE" = "200" ]; then
    echo "  ✓ Home page OK"
fi
# ... 70+ lines of shell script
```

**After** (Ansible playbook):
```bash
ansible-playbook \
    -i ${ANSIBLE_INVENTORY} \
    ${ANSIBLE_PLAYBOOK_VERIFY} \
    -v
```

---

## 5. Updated Test Scripts

**Files Updated**:
- `scripts/test-pipeline-stages.sh`
- `scripts/build-and-deploy.sh`

**Changes**:
- ✅ Both scripts now use the new verification playbook
- ✅ Fallback to manual verification if Ansible not available
- ✅ Display verification summary after successful checks
- ✅ Consistent behavior with Jenkins pipeline

---

## Files Modified

| File | Change Type | Description |
|------|-------------|-------------|
| `Jenkinsfile` | Modified | Removed archive stage, fixed WORKSPACE, added verify playbook |
| `ansible/playbooks/verify_petclinic.yml` | **NEW** | Separate verification playbook |
| `scripts/test-pipeline-stages.sh` | Modified | Use verification playbook |
| `scripts/build-and-deploy.sh` | Modified | Use verification playbook with fallback |

---

## Benefits

### 1. **Better Separation of Concerns**
- Deployment logic separate from verification logic
- Each playbook has a single responsibility
- Easier to maintain and debug

### 2. **Reusability**
- Verification playbook can be run independently
- Can be used in different pipelines or workflows
- Useful for manual verification after manual deployments

### 3. **Consistency**
- All major pipeline steps now use Ansible
- Consistent error handling across stages
- Standardized output format

### 4. **Improved Reporting**
- Visual formatting with box characters
- Verification summary file created
- Better failure diagnostics

### 5. **Maintainability**
- Changes to verification logic only need to be made in one place
- YAML is easier to read and modify than shell scripts
- Better version control and diff visibility

---

## Usage Examples

### Run Verification Independently
```bash
# Verify deployment after any deployment method
ansible-playbook ansible/playbooks/verify_petclinic.yml
```

### Run in Jenkins
The verification runs automatically as Stage 6 of the pipeline.

### Run via Test Script
```bash
# Test verification stage only
bash scripts/test-pipeline-stages.sh verify

# Test all stages
bash scripts/test-pipeline-stages.sh all
```

### Run via Build Script
```bash
# Build and deploy with automatic verification
bash scripts/build-and-deploy.sh
```

---

## Testing

### Verify the Changes Work

1. **Test verification playbook directly**:
```bash
cd /home/pet-clinic/deploy-petclinic
ansible-playbook ansible/playbooks/verify_petclinic.yml
```

2. **Test via test script**:
```bash
bash scripts/test-pipeline-stages.sh verify
```

3. **Test full pipeline locally**:
```bash
bash scripts/build-and-deploy.sh
```

4. **Test in Jenkins**:
   - Navigate to PetClinic-Pipeline
   - Click "Build Now"
   - Verify Stage 6 completes successfully

---

## Verification Summary Output

After successful verification, a summary file is created:

**Location**: `/home/pet-clinic/build/verification-summary.txt`

**Content**:
```
PetClinic Verification Report
=============================
Timestamp: 2025-11-29T10:30:45Z

Endpoint Tests:
  ✓ Home page        : HTTP 200
  ✓ Vets page        : HTTP 200
  ✓ Find owners page : HTTP 200

System Checks:
  ✓ Tomcat process   : Running (PID found)
  ✓ Tomcat port      : 9090 listening

Application URL: http://localhost:9090/petclinic

Status: ALL CHECKS PASSED ✓
```

---

## Rollback (If Needed)

If you need to revert these changes:

```bash
# Revert to previous commit
git log --oneline  # Find the commit before changes
git revert <commit-hash>

# Or manually restore old verification method
# The shell script version is preserved in git history
```

---

## Next Steps

1. ✅ Test the verification playbook independently
2. ✅ Run full pipeline in Jenkins
3. ✅ Verify summary file is created
4. ⬜ Consider adding more verification checks (optional):
   - Database connectivity test
   - Memory usage check
   - Response time thresholds
   - Health endpoint check

---

## Notes

- The verification playbook uses Ansible's `uri` module which requires `python3-urllib3`
- Retry logic ensures transient failures don't cause false negatives
- The 10-second wait allows application to stabilize after startup
- Summary file persists between builds for troubleshooting

---

**Author**: DevOps Team  
**Date**: 2025-11-29  
**Version**: 1.1  
**Status**: ✅ Tested and Verified

