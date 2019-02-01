# Slack Emoji Reactions Statistic

![Slack Emoji Reactions Statistic](https://github.com/cmichi/slack-emoji-reactions-histogram/raw/master/images/slack-emoj-reactions-statistic.png)


## How to set it up

You need to decide on a channel, find out the channel id. To do this visit
https://slack.com/api/conversations.list?limit=50 where you'll see all
available channels.

As a first step you will need to set up an [Incoming Slack Webhook](https://api.slack.com/incoming-webhooks).
At the end of this process you will get the credentials below.

	$ git clone https://github.com/cmichi/slack-emoji-reactions-histogram.git
	$ cd slack-emoji-reactions-histogram/
	$ cat > .env
	export CLIENT_ID="..."
	export CLIENT_SECRET="..."
	export VERIFICATION_TOKEN="..."
	export OAUTH_TOKEN="xoxp-..."

	export CHANNEL_ID="..."
	export CHANNEL_NAME="company-general"

	export POST_TO_CHANNEL_NAME="company-general"
	^D
	$ . .env
	$ ./reaction-stats.sh

In order to set this up as a bi-weekly cronjob:

	PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# each second wednesday at 13 utc
	0 13 * * 3 [ `expr \`date +\%s\` / 86400 \% 2` -eq 0 ] && /bin/bash /home/michi/reaction-stats.sh


## License

	Copyright (c)

	2018 Michael Mueller, http://micha.elmueller.net/

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
	LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
	WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
