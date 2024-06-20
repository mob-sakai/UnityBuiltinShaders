Unity Built-in Shaders
====

- It is important for shader package developers to find out when new shader features are added.
- This repository was created to investigate the differences between versions of Unity's built-in shaders.
- You can download the built-in shaders from https://download.unity3d.com/download_unity/${CHANGESET}/builtin_shaders-${VERSION}.zip.
  - The changesets for each Unity version can be obtained using `npx unity-changeset ${VERSION}`.
- The commit tree structure is based on https://github.com/Unity-Technologies/UnityCsReference.
- GitHub Actions and Zapier are used to automatically commit changes whenever a new version is released.
  - (Zapier) Watch the release feeds (https://unity3d.com/unity/releases.xml and https://unity3d.com/unity/beta/latest.xml) and create a new comment starting with `/run update` when new version of Unity released.
  - (GitHub Actions) Run `update` workflow when a comment starting with `/run update` is created.
    - https://github.com/mob-sakai/UnityBuiltinShaders/blob/main/.github/workflows/update.yml#L10-L11
  - If another `update` workflow is already running, the job is canceled.
    - https://github.com/mob-sakai/UnityBuiltinShaders/blob/main/.github/workflows/update.yml#L23-L24
  - `update` workflow can be run manually
