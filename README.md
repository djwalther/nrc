nrc - the little IRC client that could.

Written in newLisp, in a very few lines of code, I hacked it up to a usable
state in about 4 hours.

My goal was this: an IRC client simple enough to modify easily.  It is 100
lines of code, and written in one of the easiest of programming languages:
newLisp.  http://newlisp.org/Documentation

Every IRC client I tried, was touchy when it came to simple things like logging
channel activity in your absence, being easy to configure, to figure out, etc.

The user interface may seem strange to long time IRC users.  But once you are
used to it, you will find it simpler and more powerful.  If you have ever used
a MUD or MOO, you will feel at home right away.

When you want to chat, you don't want a client that gets in your way.  nrc gets
out of your way whereever possible.  It is like drinking water; you don't have
to think about it.  Focus on the words you are reading and typing.

REQUIREMENTS

You must have the newlisp interpreter installed to run nrc.  It is free.

STARTUP

Inspired by the design sensibility of Daniel J Bernstein, there are no command
line options to nrc.  Instead, you set environment variables.  Here is an
example I used for testing nrc:

SERVER=irc.freenode.net \
PORT=6667 \
NICK=guest300 \
USER=guest300 \
REALNAME="Take a Wild Guest" \
LOGFILE=rust.log \
./nrc.lsp

You can cut and paste and try it yourself.  Most of these things can be
configured inside the program too, using the IRC protocol.  But this method of
setting environment variables makes it easy to make a session act as you want
it to, reliably, repeatably, inside a shell script or batch file.

COMMANDS

You don't need a mouse at all.  You control nrc by typing commands to it.  You
type a command, then hit Enter or Return.

QUITTING, EXITING, LEAVING THE PROGRAM

The most important command in a program is the command to end it.  If you don't
like it, you want to get out of there fast.  It is easy.

There are three commands, all doing the same thing:

@quit
@exit
@bye

If you really want, you could also do this:

@raw QUIT

TALKING

To talk, you have to have an audience.  You can choose a channel, or a person,
to be your audience.

CHANNELS

To choose a channel, type the channel's name.

#rust

The "#" character tells nrc you want to direct your words to a channel.  It
joins the channel for you if necessary, and if possible.  To join and talk to a
channel, type the channel's name.  In other IRC programs, you have to type the
command /join #channelname.  Isn't nrc convenient?

PERSONS

To address your words to a person, there are two method: directing your words
to a person in view of others, and saying words to them in private.

PRIVATE MESSAGES

'person hi there

The ' lets nrc know you want to talk to a person in private.  You only need to
type this once.  Afterward, you are typing to that person by default.  This
only changes when you start talking to another person, or to a channel.  But,
if you want to stop directing your words at someone, even if you have noone
else in mind, it is simple: type ' on a line by itself.

'

Now you will be talking to noone until you explicitly enable it again.

PUBLIC MESSAGES

`person let's play tic-tac-toe

Then you will see:

<yourself>person: let's play tic-tac-toe

This is a way to speak in a group of people, but make it clear that your words
are meant for one person in particular.

After the first time, you can keep talking to the person in public like this:

` on second thoughts, I'd prefer a game of monopoly
<yourself>person: on second thoughts, I'd prefer a game of monopoly

When nrc sees "` " to start the line, it knows you want to direct your words at
the same person as before.

You can clear this entirely by putting ` on a line by itself.  You will
continue speaking to the channel, but more generally.

ACTIONS

Sometimes you are talking, then you see another person in the channel do an
action.  Eg:

Normal speech looks like this:

<SamWise> Hi Frodo, how's it going?

An action looks like this:
SamWise throws the ring into the pond.

In nrc, you do an action very easily; you type

:throws the ring into the pond.

The : character at the beginning of the line tells nrc you want to do an
action.  This is how actions are done in MOO software.  IRC normally has the
command "/me does the action"

MISC

@raw <text>
  The @raw command let's you pass text directly to the IRC server.  This is
helpful for debugging, and let's you do things that IRC allows, but that aren't
(yet) supported by the nrc client.

FEATURES

Logging

If you set the environment variable LOGFILE, nrc will log every line to the logfile.

Timestamping

Every line in the logfile is timestamped.  This allows you to do replays,
correlation of emails and other data, etc.  The timestamp is the standard Unix
timestamp, a single integer value counting seconds since 1969.  This makes the
logfile less cluttered, and easy to parse with tools like awk, perl, and
newLisp.
