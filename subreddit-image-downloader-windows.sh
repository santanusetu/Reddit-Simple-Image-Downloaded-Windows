#!/bin/bash
#
# Fetches a bunch of images or gifs from a particular subreddit and arranges them in an html page.
# 
# Dependencies: jq (`brew install jq`) - use Chocolatey for windows (it's homebrew equivalent for windows)
#
# USAGE:
#   reddit [-p|--max-pages MAX_PAGES] [-t|--top [day|week|month|year|all]] SUBREDDIT_NAME

# EXAMPLE: 
# sh subreddit-image-downloader-windows.sh subredditName -t all


# Globals
jsonFile=/tmp/reddit.json
htmlFile=/tmp/reddit.html
maxPages=3
limit=100
top=""

# Parse the options
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -p|--max-pages)
        maxPages=$2
        shift;shift
        ;;

        -t|--top)
        top=$2
        shift;shift
        ;;

        *)  # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# Construct the proper HTTP GET query and the header for the resulting page.
query="https://www.reddit.com/r/$1/.json?limit=$limit"
header="<a href=\"https://www.reddit.com/r/$1\">/r/$1</a>"
if [ "$top" != "" ]
    then
        query="https://www.reddit.com/r/$1/top/.json?limit=$limit&sort=top&t=$top"
        header="<a href=\"https://www.reddit.com/r/$1/top?sort=top&t=$top\">/r/$1 - Top: $top</a>"
fi


# 1. Curls for the subreddits JSON
# 2. Filters out everything but the jpgs, pngs and gifs, retaining the "title", "permalink", and "url" of each post.
# 3. Dumps a formatted div of each post's data to the $htmlFile
# 4. Set's the `after` variable, so we can query again for the next page potentially.
function dumpRedditImagesToHTMLFile()
{
    local thisQuery=$1
    curl -q -A "GetRedditImagesBot" "$thisQuery" 2> /dev/null > $jsonFile
    cat $jsonFile | jq '.data.children[].data | select(.url | contains(".jpg") or contains(".png") or contains(".gifv")) | {url, permalink, title}' \
        | sed 's:\.gifv:\.gif:' \
        | jq -s '.' \
        | jq -r '.[] | 

        "<div style=\"display: flex; flex-direction: column; text-align: center; border: 1px ridge gold; margin: 10px; float: left; box-shadow: 0 0 10px #ccc\">
            <a style=\"display: inline-block; max-width: 300px; vertical-align: middle; padding-top: 15px; color: red \">" + .title + "</a>
                <a target=\"_blank\" href=\"" + .url + "\">
                    <img src=\"" + .url + "\" style=\"width:300px; height :300px; padding: 5px; padding-top: 15px; padding-bottom: 15px \">
                </a>
            <a target=\"_blank\" href=\"http://www.reddit.com" + .permalink + "\" style=\"display: inline-block; max-width: 300px; padding-bottom: 15px\">" + .url + "</a>
        </div>"' \
        >> $htmlFile
    after=$(cat $jsonFile | jq -r '.data.after')
}


# HTML Header
echo "<html>
        <head>
            <title>Reddit Images for: $1</title>
                </head>
                    <body>
                        <h1 align=\"center\">$header</h1>
                        <div style=\"display: flex; flex-wrap: wrap; align-items: center\">" > $htmlFile

# First Page
if [ $maxPages -gt 1 ]; then
    echo "Fetching page 1/$maxPages..."
fi
dumpRedditImagesToHTMLFile $query

# Rest of the pages
page=2
while [ $page -le $maxPages ]
do
    if [ "$after" != "null" ]; then
        echo "Fetching page $page/$maxPages..."
        echo "<h1 align=\"center\" style=\"width: 100%\">Page $page</h1>" >> $htmlFile
        dumpRedditImagesToHTMLFile "${query}&after=$after"
    else
        echo "No more pages found!"
        break
    fi
    page=$(($page + 1)) # Bump the counter
done

# HTML Footer
echo '</div></body></html>' >> $htmlFile

start $htmlFile