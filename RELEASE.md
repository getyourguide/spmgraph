# Release process

Once the main branch has the fixes and features that should be shipped:
1. Start the [release workflow](https://github.com/getyourguide/spmgraph/actions/workflows/release.yml)
   - Fill in the `updateType` argument, which follows [semver](https://semver.org/)
2. Sit and wait 🙃! The automation will
   - Bump the version following the update type
   - Create a new tag and release
   - Auto-generate release notes
