export DAYS=14

# TODO test if limit works
function get_members {
  local API_URL=$1; shift
  local LIMIT=$1; shift

  BASE_URL="$API_URL&limit=$LIMIT"
  AGGREGATED_RESULT=""
  while true;
  do
    URL="$BASE_URL"
    if [ ! -z "$CURSOR" ];
    then
      URL="$URL&cursor=$CURSOR"
    fi

    echo "$URL" >&2
    RESULT=$(curl --compressed \
      -X GET \
      -H "Authorization: Bearer $OAUTH_TOKEN" \
      "$URL")

    CONTENT=$(echo "$RESULT" | jq -r '.members' | tr -d ',"][ ' | egrep -v '^\s*$')
    AGGREGATED_RESULT=$(echo -e "$CONTENT\n$AGGREGATED_RESULT")

    CURSOR=$(echo "$RESULT" | jq -r '.response_metadata.next_cursor')
    if [ -z "$CURSOR" ];
    then
      # no pagination information is present in response
      break
    fi
  done
  AGGREGATED_RESULT=$(echo "$AGGREGATED_RESULT" | egrep -v '^\s*$')
  echo "$AGGREGATED_RESULT"
}

function get_reactions_for_member {
  local MEMBER=$1; shift
  local API_URL=$1; shift
  local CREATED_AFTER=$1; shift

  AGGREGATED_RESULT=""
  CURRENT_PAGE=""
  while true;
  do
    URL="$API_URL"
    if [ ! -z "$CURRENT_PAGE" ];
    then
      PAGE=$(($CURRENT_PAGE + 1))
      URL="$URL&page=$PAGE"
    fi

    echo "url: $URL" >&2

    RESULT=$(curl --compressed \
      -X GET \
      -H "Authorization: Bearer $OAUTH_TOKEN" \
      "$URL")

    # filter result for timestamp
    function filter_after_timestamp {
      local RESULT=$1; shift
      local AFTER_TS=$1; shift

      FILTERED_RESULTS=""
      LINES=$(echo "$RESULT" | jq -c '.items[]')
      echo "$LINES" | while read -r LINE ; do
        WHEN=""

        # extract ts, timestamp or created_at   
        TS=$(echo "$LINE" | jq -r '.. | .ts? | select(. != null)' | head -n1)
        TIMESTAMP=$(echo "$LINE" | jq -r '.. | .timestamp? | select(. != null)' | head -n1)
        CREATED=$(echo "$LINE" | jq -r '.. | .created? | select(. != null)' | head -n1)
        if [ ! -z "$CREATED" ]; then WHEN="$CREATED";
        elif [ ! -z "$TS" ]; then WHEN="$TS";
        elif [ ! -z "$TIMESTAMP" ]; then WHEN="$TIMESTAMP"; fi

        WHEN=$(echo "$WHEN" | cut -d '.' -f 1)

        if [[ $WHEN > $AFTER_TS ]];
        then
          #echo "filter: $WHEN > $AFTER_TS" >&2
          echo "$LINE"
        #else 
          #echo "filtered out because: $WHEN > $AFTER_TS" >&2
        fi
      done
    }

    AFTER_TS=$(date +%s)
    AFTER_TS=$(($AFTER_TS - (60 * 60 * 24 * $DAYS)))
    FILTERED_RESULT=$(filter_after_timestamp "$RESULT" "$AFTER_TS" | jq -s)
    LENGTH=$(echo "$FILTERED_RESULT" | jq 'length')
    if [[ "$LENGTH" -eq 0 ]];
    then
      echo "no result present after filtering" >&2
      echo -n >> "/tmp/aggregated-result-$MEMBER"
      break
    fi

    # count only if user id is in the users array
    REACTIONS=$(echo "$FILTERED_RESULT" | jq -c ".[]")

    echo "$REACTIONS" | while read -r LINE ; do
      if [ -z "$LINE" ];
      then
        continue
      fi

      # extract ts, timestamp or created_at   
      TS=$(echo "$LINE" | jq -r '.. | .ts? | select(. != null)' | head -n1)
      TIMESTAMP=$(echo "$LINE" | jq -r '.. | .timestamp? | select(. != null)' | head -n1)
      CREATED=$(echo "$LINE" | jq -r '.. | .created? | select(. != null)' | head -n1)
      if [ ! -z "$CREATED" ]; then WHEN="$CREATED"; 
      elif [ ! -z "$TS" ]; then WHEN="$TS"; 
      elif [ ! -z "$TIMESTAMP" ]; then WHEN="$TIMESTAMP"; fi

      CONTENT=$(echo "$LINE" | jq -r ". | .. | .reactions? | select(. != null) | .[] | select(.users | contains([\"$MEMBER\"])) | \":\" + .name + \":\t\" + \"-$WHEN.\"")
      echo "$CONTENT" >> "/tmp/aggregated-result-$MEMBER"
    done

    CURRENT_PAGE=$(echo "$RESULT" | jq -r '.paging.page')
    PAGES=$(echo "$RESULT" | jq -r '.paging.pages')
    if [ $CURRENT_PAGE -eq $PAGES ] || [ $PAGES -eq 0 ] ;
    then
      # no pagination information is present in response
      echo "continuing because no pagination info" >&2
      break
    fi
  done
}

function get_reactions {
  rm -f /tmp/all-reactions
  local MEMBERS=$1; shift
  ALL=""
  NO=0
  OF=$(echo "$MEMBERS" | wc -l)

  function process_member {
    local MEMBER=$1; shift
    NO=$(($NO + 1))
    echo "Getting reactions for $MEMBER" >&2
    URL="https://slack.com/api/reactions.list?user=$MEMBER"
    AFTER_TS=$(date +%s)
    AFTER_TS=$(($AFTER_TS - (60 * 60 * 24 * $DAYS)))

    get_reactions_for_member "$MEMBER" "$URL" "$AFTER_TS"
    cat "/tmp/aggregated-result-$MEMBER" | sort | uniq | cut -f 1 | egrep -v '^\s*$' >> /tmp/all-reactions
    rm -f "/tmp/aggregated-result-$MEMBER"

    function preprocess {
      echo "$1" | while read -r line ; do
        if [ -z "$line" ];
        then
          # no line is present
          echo "no results here, continuing" >&2
          continue
        fi

        COUNT=$(echo "$line" | cut -f 1)
        ALIAS=$(echo "$line" | cut -f 2)
        yes "$ALIAS" | head -n "$COUNT"
      done
    }
  }

  export -f process_member
  export -f get_reactions_for_member
  set +o allexport
  echo "$MEMBERS" | xargs -n1 -P10 -I% bash -c 'process_member "%"'
}

MEMBERS=$(get_members "https://slack.com/api/conversations.members?channel=$CHANNEL_ID" 50)
echo "There are " $(echo "$MEMBERS" | wc -l) " members". >&2

get_reactions "$MEMBERS"
STATISTIC=$(cat /tmp/all-reactions | sort | uniq -c | sort -n -r | head -n 15 | awk -F ' ' '{print $2 "  " $1}')

TEXT="These are the fifteen most used reactions by members of #$CHANNEL_NAME in public channels during the last $DAYS days:\n$STATISTIC"
curl -H "Content-Type: application/json; charset=utf-8" -X POST -d "{\"channel\":\"#$POST_TO_CHANNEL_NAME\",\"text\":\"$TEXT\"}" -H "Authorization: Bearer $OAUTH_TOKEN" "https://slack.com/api/chat.postMessage"
