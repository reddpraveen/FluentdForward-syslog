# Standardized GitHub OCP Operator Repository Creation Workflow

## Overview
This document describes the automated workflow for creating new OCP operator management repositories in GitHub. The workflow ensures all new repos follow best practices, have a standardized structure, and are ready for GitOps, CI/CD, and release automation.

## Key Features
- Automated creation of three branches: **master**, **dev/initial**, and **stable**
- Initial Pull Request (PR) from **dev/initial** to **stable**
- Standardized folder and file structure for OCP operator management
- Automatic injection of CI and release automation workflows
- Copying of collaborators, branch protection rules, and repo settings from a source repo
- Parameterized for team/project-specific customization

## Workflow Inputs
| Input               | Description                                              | Default                  |
|---------------------|----------------------------------------------------------|--------------------------|
| source_repo         | Source repository to copy structure/settings from        | RHVaultSecretsOperator   |
| destination_repo    | New repository to create (owner/new-repo)                | (user input)             |
| folder_prefix       | Prefix for instance/operator folders (e.g., vso)         | (user input)             |
| cluster_config_type | Cluster config type: single or separate (azure/hci)      | (user input)             |

## Branching Model
- **master**: Contains only a README.md with repo name and description.
- **dev/initial**: Contains the full OCP operator structure and all files.
- **stable**: Identical to dev/initial at creation.
- **Initial PR**: Automatically created from dev/initial to stable for manual review and merge.

## Folder and File Structure
- `applications/app-config/caas-appliation-instance.yaml`: ArgoCD Application, with new repo name.
- `applications/base`, `applications/overlays`: Each with kustomization.yaml (referencing instance.yaml) and an empty instance.yaml.
- `applicationset/sample-applicationset.yaml`: Sample ApplicationSet, with new repo name.
- `<prefix>-operator/`: Chart.lock, Chart.yaml, README.md (with new repo name), templates/, empty values-dev.yaml, values-uat.yaml, values.yaml.
- `<prefix>-instance/`: 
  - If *single*: base/ and overlays/ (each with kustomization.yaml and instance.yaml).
  - If *separate*: azure/base, azure/overlays, hci/base, hci/overlays (each with kustomization.yaml and instance.yaml).
- `.github/CODEOWNERS`: Created with a placeholder for future update.
- `.github/workflows/ci.yml`: Default CI workflow.
- `.github/workflows/auto-release.yml`: Auto-release workflow to tag releases on PR merge to stable.
- `.gitignore`: Contains `<prefix>-operator/charts`.

## Repo Settings and Permissions
- **Collaborators**: Copied from source repo.
- **Branch protection rules**: Copied from source repo.
- **Repo settings**: Description, topics, and visibility copied from source repo.

## Automation and Best Practices
- Strict error handling in shell scripts.
- Reusable shell function for kustomization.yaml/instance.yaml creation.
- Detailed output summary at the end of the workflow.

## Release Automation
- **auto-release.yml**: Ensures every PR merged to stable triggers a new release tag and GitHub release.

## Step-by-Step Standardized Repo Creation Procedure

1. Go to the Actions tab in the GitHub repository where the workflow is installed.
2. Select the **duplicate-ocp-repo** workflow.
3. Click **Run workflow**.
4. Fill in the required inputs:
    - **source_repo**: (defaults to RHVaultSecretsOperator, or specify another)
    - **destination_repo**: (e.g., your-org/my-new-operator-repo)
    - **folder_prefix**: (e.g., vso)
    - **cluster_config_type**: single or separate
5. Click **Run workflow** to start the process.
6. The workflow will:
    - Check if the destination repo exists (fails if it does).
    - Create the new repo and initialize three branches: master, dev/initial, stable.
    - Populate master with only a README.md.
    - Populate dev/initial and stable with the full OCP structure and files.
    - Copy collaborators, branch protection, and repo settings from the source repo.
    - Inject CODEOWNERS, CI, and auto-release workflows.
    - Open a PR from dev/initial to stable.
7. After the workflow completes:
    - Review and approve the PR from dev/initial to stable.
    - When the PR is merged, a release tag will be created automatically.

## Customization
- Update the CODEOWNERS file in `.github/CODEOWNERS` as needed.
- Add or modify files in the repo as required for your team/project.
- The `.gitignore` file is pre-populated to ignore `<prefix>-operator/charts`.

## FAQ

**Q: How is the auto-release enabled?**  
A: The workflow injects `.github/workflows/auto-release.yml` into every new repo, which triggers a release tag on PR merge to stable.

**Q: Can I change the default source repo?**  
A: Yes, you can override the source_repo input when running the workflow.

**Q: What if I want to add more files or folders?**  
A: You can edit the workflow or manually add files after repo creation.

## Contact
For questions or help with this workflow, contact your DevOps team or the workflow maintainers. 