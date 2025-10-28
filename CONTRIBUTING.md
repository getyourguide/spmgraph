# Contributing

When contributing to this repository, we encourage you to first discuss the change you wish to make via an issue before submitting a change. 
We're not strict about this, and for small changes, feel free to open a pull request directly.

## Local development
To run it locally during development:

#### CLI
run `swift run spmgraph <command> <options>`

#### Xcode (with the debugger attached)

Leverage the [shared spmgraph xcscheme](./.swiftpm/xcode/xcshareddata/xcschemes/spmgraph.xcscheme)
  - Update the scheme with a custom working directory
  - Update the arguments with the path to your Package.swift
  - **Do not commit** such changes

The spmgraph config package depends on spmgraph itself, and by default uses the latest release. Update the reference, in `Sources/SPMGraphConfigSetup/Resources/Package.txt`, to your working branch in order to have `spmgraph` changes take effect in the spmgraph config part

## Pull Request Process

- Aim to keep pull requests scoped to one feature to ease review
- Add tests to verify that the changes work (if possible)
- Include or update documentation for new or changed features
