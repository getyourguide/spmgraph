# Release process

Once the main branch has the fixes and features that should be shipped:
1. Start the `release.yml`
   - Fill in the `updateType` argument, which follows [semver](https://semver.org/)
2. Sit and wait :)! The automation will
   - Bump the version follow the update type
   - create a tag and the release
   - auto generate release notes
