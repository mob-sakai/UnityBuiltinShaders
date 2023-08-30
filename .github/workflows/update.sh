#!/bin/bash -ex

# Find all Unity tags
npx unity-changeset list --minor-versions --latest-patch > unity_minor_versions
npx unity-changeset list --versions > unity_versions
git clone https://github.com/Unity-Technologies/UnityCsReference.git
git -C UnityCsReference tag | while read -r tag; do
    echo "$(git -C UnityCsReference show -s --format='%cI '$tag' %h %p' $tag)"
done \
| sort > unity_tags
rm -rf UnityCsReference


# Checkout each tag and build-in shaders
cat unity_tags | while read -r t version h p ; do
    # Skip if already tagged
    if git show -s $version > /dev/null 2>&1 ; then
        echo $version is already tagged
        continue
    fi
    
    # Get changeset and parent version
    changeset=`npx unity-changeset $version || :`
    parent=`grep -e $version' ' unity_tags | cut -d ' ' -f 4 | xargs -I {} grep -e ' {} ' unity_tags | cut -d ' ' -f 2`
    
    # Checkout parent version
    if [ -z "$parent" ]; then
        git checkout -f main
    elif git show -s $parent > /dev/null 2>&1 ; then
        git checkout -f $parent
    else
        continue
    fi
    
    # Update readme
    echo -e "Unity Built-in Shaders\n====\n\n$version ($changeset)" > README.md
    git add README.md
    
    message="$version"
    # Update builtin_shaders
    if [ -n "$changeset" ]; then
        message="$version ($changeset)"

        # Download builtin_shaders
        rm -rf builtin_shaders || :
        mkdir -p builtin_shaders
        
        if [ "$(uname)" == 'Darwin' ]; then
            curl https://download.unity3d.com/download_unity/${changeset}/builtin_shaders-${version}.zip | tar xvf - -C builtin_shaders
        else
            wget https://download.unity3d.com/download_unity/${changeset}/builtin_shaders-${version}.zip -O builtin_shaders.zip \
            && unzip builtin_shaders -d builtin_shaders && rm builtin_shaders.zip
        fi
        
        git add builtin_shaders
    fi

    
    git commit -m "$message"
    git commit --amend --date="$t" -m "$message"
    git rebase HEAD~1 --committer-date-is-author-date

    git tag $version
    git push origin $version
done


# tag 'main' on latest release
cat unity_versions | while read -r version ; do
    if git show -s $version > /dev/null 2>&1 ; then
        git branch -f main $version
        git push -f origin main
        echo "main -> $version"
        break
    fi
done


# tag minor versions on latest patch
cat unity_minor_versions | while read -r minor_version ; do
    grep $minor_version unity_versions | while read -r version ; do
        if git show -s $version > /dev/null 2>&1 ; then
            git branch -f $minor_version $version
            git push -f origin $minor_version
            echo "$minor_version -> $version"
            break
        fi
    done
done