#!/bin/bash

git fetch --tags

INDEX_LIST=""

mkdir -p tmp/temp_clone
git clone . tmp/temp_clone
pushd tmp/temp_clone

mkdir public

RELEASE_TAGS_FULL=$(git tag -l "v[0-9]*")
RELEASE_TAGS=$(echo "$RELEASE_TAGS_FULL" | sed 's/^v//')
echo "RELEASE_TAGS: $RELEASE_TAGS"

HTML_ROW_CODE_FMT="<li><a href=\"%s\">%s</a></li>"
ALL_ARCHIVE_NAME="all.tar.gz"

function format_list_row() {
    href="$1"
    text="${2:-$href}"

    printf "${HTML_ROW_CODE_FMT}" "$href" "$text"
}

function prepare_tarball_content() {
    local tarball_content_dir="$1"
    cp -r --dereference lib "$tarball_content_dir/ci"
    cp -r conf "$tarball_content_dir/ci/conf"
    cp depends.txt "$tarball_content_dir/ci/conf/"
    if [ -d checksums ]; then
        cp -r checksums "$tarball_content_dir/ci/checksums"
    fi
    cp -r template "$tarball_content_dir/ci/template"
}

for version in $RELEASE_TAGS_FULL; do
    echo "Preparing version: $version"
    export VERSION=$(echo "$version" | sed 's/^v//')
    echo "VERSION=$VERSION"
    tag_versions=$(../../lib/latest-tags.sh | tr "," " ")
    echo "  Shorted (tagged) versions are: $tag_versions"
    # dokoncil jsem minulou major radu? tj. zacla prave nova major verze?
    for tag_version in $tag_versions; do
        # make symbolik link for (old) major version to full specified version
        pushd public
        [ "$tag_version" != "latest" ] && tag_version=v$tag_version
        ln -s $version "$tag_version"
        row="$(format_list_row "$tag_version")"
        INDEX_LIST="$INDEX_LIST\n$row"
        popd
    done

    # prepare version files
    git reset --hard
    git checkout $version
    git clean -fxd -e public

    mkdir -p public/$version
    prepare_tarball_content public/$version
    pushd public/$version
    tar czf "$ALL_ARCHIVE_NAME" ci
    VERSION_INDEX_LIST=
    for file in $(find ci -type f); do
        row="$(format_list_row "$file")"
        VERSION_INDEX_LIST="$VERSION_INDEX_LIST\n$row"
    done
    row="$(format_list_row "$ALL_ARCHIVE_NAME")"
    VERSION_INDEX_LIST="$VERSION_INDEX_LIST\n$row"
    echo -e "$VERSION_INDEX_LIST" > index.html
    popd
    row="$(format_list_row "$version")"
    INDEX_LIST="$INDEX_LIST\n$row"
done

echo -e "$INDEX_LIST" > public/index.html
popd

mv tmp/temp_clone/public .
