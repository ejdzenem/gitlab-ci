# Deploy component(s): ${COMPONENT} ${TAG_VERSION}

- [x] Pipeline URL: ${CI_PIPELINE_URL}
- [x] Responsible person: ${AUTHOR_USERNAME}
- [x] The changes were tested in dev
- [ ] The changes were reviewed by product owner in pre-production namespace (it's not mandatory).


## Is the release backward compatible?
- [${VERSION_MAJOR_CHECKBOX}] No - major version
    - [${VERSION_MAJOR_CHECKBOX}] Is the release correctly tagged? (x.0.0)
    - [ ] Dependencies on newer version of other component(s) or db-migrations: (link(s) on RT(s)/issue(s)) above
    - [ ] We have to do locality switchover to release all dependent components
    - [ ] Rollback to: ``
- [${VERSION_MINOR_CHECKBOX}] Yes - minor or patch version
    - [${VERSION_MINOR_CHECKBOX}] Is the release correctly tagged? ([0-9]+.x.x)
    - [${VERSION_MINOR_CHECKBOX}] AdminsBrno1 could deploy or rollback to previous version without locality switchover
    - [ ] No changes in database schema

## Changes in application dependencies
- [ ] following dependency components were removed: ``
- [ ] following dependency components were added:   ``

# Other description (such as changes or any other information you want to provide)

${COMMIT_LIST}
${ADDITIONAL_ISSUE_DESCRIPTION}

.....

__FYI: put `/label ~critical` on the beginning of line in case of critical.__

**In case the deployment was reverted, add label `~reverted`**

/label ~"new deploy"
