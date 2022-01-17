#!/usr/bin/env bash
set -euo pipefail

mkdir -p gen/
WRITINGS_INDEX_FILE=./gen/writings_index.md
WRITINGS_FILE=./gen/writings.md
WRITINGS_URI=/pages/writings.html

TIMELINE_INDEX_FILE=./gen/timeline_index.md
TIMELINE_FILE=./gen/timeline.md
TIMELINE_URI=/pages/timeline.html

OLDIFS=$IFS

#------

function get_headers() {
    IFS=$'\n'
    for a in $(ag --noheading --nobreak --nonumbers "$@" | awk 'BEGIN{FS=":"} {print $1 $3}' | sort -k2); do
        IFS=$OLDIFS b=( $a )
        F=${b[0]}
        F=${F/.md/.html} # fix file extension
        F=${F/content/} # remove path prefix
        VAL=${b[@]:1}
        VAL=${VAL//\"/}
        echo "${F} ${VAL}"
    done
    IFS=$OLDIFS
}

#------

echo -n "Generating timeline..."

# a dictionary by year with all files that have a pub date
declare -A YEARS
# list all files with publication dates
while read -r a; do
    b=( $a )
    F=${b[0]}
    YEAR=${b[1]}
    YEAR=${YEAR:0:4}
    if [ -v YEARS[$YEAR] ]; then
        l=${YEARS[$YEAR]}
        l+="|$F"
        YEARS[$YEAR]=$l
    fi
    if [ ! -v YEARS[$YEAR] ]; then
        l=$F
        YEARS[$YEAR]=$l
    fi
done < <(get_headers "^PubDate: " content)


# a dictionary by filename with associated title
declare -A TITLES
# lookup titles
while read -r a; do
    b=( $a )
    F=${b[0]}
    TITLE=${b[@]:1}
    TITLE=${TITLE//\"/}
    TITLES[$F]=$TITLE
done  < <(get_headers "^title: " content)

SORTED_YEARS=$(for k in "${!YEARS[@]}"
               do
                   echo $k
               done | sort)

cat > ${TIMELINE_INDEX_FILE} <<- EOM
---
title: Timeline Index
---

EOM

echo "<a name=top></a>" >> ${TIMELINE_INDEX_FILE}
# generate the shortcut navigation per year
for key in $(echo ${SORTED_YEARS}); do
    echo "<a href=\"${TIMELINE_URI}#${key}\">${key}</a>" >> ${TIMELINE_INDEX_FILE}
done

cat > ${TIMELINE_FILE} <<- EOM
---
title: Timeline
---

<p>
<!--#include virtual="/pages/timeline_index.html" -->
</p>
<hr/>
EOM

for key in $(echo ${SORTED_YEARS}); do
    l=${YEARS[$key]}
    echo -n "${key} "
    echo "<span id=\"${key}\"></span><br/><br/><h2>${key}</h2><ul>" >> ${TIMELINE_FILE}
    IFS="|"
    for x in ${l[@]}; do
        echo "<li><a href=\"${x}\">${TITLES[$x]}</a></li>" >> ${TIMELINE_FILE}
    done
    IFS=$OLDIFS
    echo "<li><a href=\"#top\">Back to top</a>.</li>" >> ${TIMELINE_FILE}
    echo "</ul>" >> ${TIMELINE_FILE}
done
echo "done"

# ------

echo -n "Generating works..."

function make_title() {
    in="${1//-/ }" # replace all - with space
    in=( $in )     # create array
    echo ${in[@]^} # capitalize every word
}

WORKS_DIR=content/works
CATEGORIES=( 'major-works' 'essays' 'letters' 'works-removed-from-the-paine-cannon' 'recently-discovered' )

excludes=( )
for C in ${CATEGORIES[@]}; do
  excludes+=( -not -name ${C} )
done
UNKNOWN_CATEGORIES=$(find ${WORKS_DIR} -mindepth 1 -maxdepth 1 "${excludes[@]}")
if [ "${UNKNOWN_CATEGORIES}" != "" ]; then
    echo "Found unexpected category when validating ${WORKS_DIR}: ${UNKNOWN_CATEGORIES}"
    exit 1
fi

cat > ${WRITINGS_INDEX_FILE} <<- EOM
---
title: Writings Index
---

<p>
EOM

# generate the shortcut navigation
echo "<a name=top></a>" >> ${WRITINGS_INDEX_FILE}
for key in ${CATEGORIES[@]}; do
    TITLE=$(make_title ${key})
    echo "<a href=\"${WRITINGS_URI}#${key}\">${TITLE}</a><br/>" >> ${WRITINGS_INDEX_FILE}
done
echo "</p>" >> ${WRITINGS_INDEX_FILE}

# ------

cat > ${WRITINGS_FILE} <<- EOM
---
title: Writings
---

<p>
<!--#include virtual="/pages/writings_index.html" -->
</p>
<hr />
<ul>
EOM

# generate the writings
for key in ${CATEGORIES[@]}; do
    TITLE=$(make_title ${key})
    echo -n "${key} "
    echo "" >> ${WRITINGS_FILE}
    echo "<li><a name=\"${key}\"></a><h4>${TITLE}</h4><ul>" >> ${WRITINGS_FILE}

    echo "<!-- BEGIN TOP LEVEL -->" >> ${WRITINGS_FILE}

    # list all top-level files with titles
    IFS=$'\n'
    for a in $(ag --noheading --nobreak --nonumbers '^title: ' content/works/${key} --depth 0 | awk 'BEGIN{FS=":"} {print $1 $3}' | sort -k2); do
        IFS=$OLDIFS b=( $a )
        F=${b[0]}
        F=${F/.md/.html} # fix file extension
        F=${F/content/} # remove path prefix
        TITLE=${b[@]:1}
        TITLE=${TITLE//\"/}
        echo "[${F}] [${TITLE}]"
        echo "<li><a href=\"${F}\">${TITLE}</a></li>" >> ${WRITINGS_FILE}
    done
    IFS=$OLDIFS

    echo "<!-- BEGIN SECTION -->" >> ${WRITINGS_FILE}

    # do each section
    for s in $(find content/works/${key} -mindepth 1 -maxdepth 1 -type dir | xargs basename | sort); do
        echo "<li>$(make_title $s)<ul>" >> ${WRITINGS_FILE}
        IFS=$'\n'
        for a in $(ag --noheading --nobreak --nonumbers '^title: ' content/works/${key}/${s} | awk 'BEGIN{FS=":"} {print $1 $3}' | sort -k2); do
            IFS=$OLDIFS b=( $a )
            F=${b[0]}
            F=${F/.md/.html} # fix file extension
            F=${F/content/} # remove path prefix
            TITLE=${b[@]:1}
            TITLE=${TITLE//\"/}
            echo "[${F}] [${TITLE}]"
            echo "<li><a href=\"${F}\">${TITLE}</a></li>" >> ${WRITINGS_FILE}
        done
        IFS=$OLDIFS
        echo "</ul></li>" >> ${WRITINGS_FILE}
    done
    echo "</ul></li>" >> ${WRITINGS_FILE}
    echo "<li><a href=\"#top\">Back to top</a>.</li>" >> ${WRITINGS_FILE}
done

echo "</ul>" >> ${WRITINGS_INDEX_FILE}

echo "done"