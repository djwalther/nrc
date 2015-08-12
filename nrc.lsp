#!/usr/bin/newlisp
#
# nrc.lsp Copyright (c) 2015 David Walther
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# A little IRC client that is also a logging bot.  For the little kid who is
# sent to bed early while the adults stay awake, and wonders what he is missing
# out on.

# UI based on Lambdamoo and irssi
# @command (quit/bye/exit, join, part/leave, topic, kick, ban, gag/ignore, op, watch, away, back, raw, whois, whowas, help, invite, knock, list, names, mode, notice, rules, motd)
# `nick text ``nick `` -
# 'nick text ''nick ''
# #channel #

# scrolling: allow page up and page down, also line at a time 

(define leftarrow (char 8592)) ; right arrow in unicode
(define rightarrow (char 8594)) ; left arrow in unicode

(define server    (env "SERVER"))
(define port (int (env "PORT")))
(define password  (env "PASS"))
(define nick      (env "NICK"))
(define user      (env "USER"))
(define realname  (env "REALNAME"))
(define keepalive 0)
(define sock nil)
(define curchan "")
(define curuser "")

(if (env "LOGFILE") (set 'logfd (open (env "LOGFILE") "append")))

# Because of IRC's Scandinavian origin, the characters {}|^ are
# considered to be the lower case equivalents of the characters []\~,
(define (irc-lower-case str)
  (replace "{" str "[")
  (replace "}" str "]")
  (replace "|" str "\\")
  (replace "^" str "~")
  (lower-case str)
)

(define (parse-nickname str)
  (regex "^:([^!]+)!" str) (if $1 $1 str))

(define (parse-irc-line l (style nil))
  (when (= style 'log)      ; strip out the timestamp
    (pop l 0 (+ 1 (find " " l))))
  (letn (lst (parse l " ")
         idx (find ":" (1 (parse l " ")) (fn (a b) (starts-with b a))))
      (if idx
        (append (0 (+ 1 idx) lst) (list (1 (join ((+ 1 idx) lst) " "))))
        (parse l " "))))

(define (print-irc timestamp buf)
  (let (l (parse-irc-line buf) n nil c "")
    (when (= ":" (first (first l)))
      (set 'n (parse-nickname (pop l))))
    (set 'c (upper-case (pop l)))
    (cond
      ((= c "PING") nil)
      ((= c "PONG") nil)
      ((= c "JOIN") nil)
      ((= c "PART") nil)
      ((= c "QUIT") nil)
      ((= c "USER") nil)
      ((= c "WHOIS") nil)
      ((= c "NAMES") nil)
      ((= c "NOTICE") (println c rightarrow (l 0) " " (l 1)))
;      ((= c "MODE") (println n " changed mode for " (l 2) " on channel " (l 1) " to " (l 0)))
      ((= c "NICK")
        (println "!! " (if n (string n " is") "You are") " now known as " (l 0))
        (unless n (set 'nick (l 0)))) ; we don't send a prefix, so we're changing our own nick
      ((= c "PRIVMSG")
        (if (= "#" (first (l 0)))
          (println "[" (l 0) leftarrow (or n nick) "] " (l 1))
          (if n
            (println n rightarrow " " (l 1))
            (println (l 0) leftarrow " " (l 1)))))
      (true (println buf)))))

;; Send IRC protocol to the server, log it to disk, and display it in a friendly format.
(define (send&print)
  (let (buf (apply string (args)) stamp (string (date-value) " "))
    (print-irc stamp buf)
    (if logfd (write logfd (string stamp buf "\n")))
    (unless (net-send sock (string buf "\r\n"))
      (println "newLisp send error: " (net-error))
      (exit)))
    (set 'keepalive (date-value)))

(define (PONG msg)  (send&print "PONG :" msg))
(define (PING)      (send&print "PING :" actualserver))
(define (QUIT)      (send&print "QUIT" (if (args) (string " :" (apply string (args))) "")) (exit))
(define (JOIN chan) (send&print "JOIN " chan) (set 'curchan chan))
(define (PART chan) (if (starts-with chan "#") (send&print "PART " chan)) (set 'curchan ""))
(define (SAY msg chan) (send&print "PRIVMSG " (or chan curchan) " :" msg))
(define (DSAY msg)  (send&print "PRIVMSG " curchan " :" curuser ": " msg))
(define (QUERY msg) (regex "^([^ ]+) (.*)$" msg 0) (set 'curchan $1) (SAY $2))
(define (PAGE msg) (regex "^([^ ]+) (.*)$" msg 0) (set 'lastpaged $1) (SAY $2 $1))
(define (REPEATPAGE msg) (SAY msg (or lastpaged curchan)))
(define (EMOTE msg) (send&print "PRIVMSG " curchan " :ACTION " msg ""))
(define (CHANLIST)  (send&print "LIST"))
(define (WHOIS user) (send&print "WHOIS " user))
(define (NAMES chan) (send&print "NAMES " (or chan curchan)))

;; translates text input from the keyboard, into actual IRC commands
(define (translate_input)
  (letn (i (apply string (args)) ii (lower-case i))
    (cond
     ((empty? i) nil) ; do nothing
     ((starts-with ii "@whois ") (WHOIS (7 i)))
     ((= "##" i)                (PART curchan))
     ((starts-with ii "#")      (JOIN i))
     ((starts-with ii "@@")     (SAY (1 i)))
     ((= "@q" ii)               (QUIT))
     ((= "@quit" ii)            (QUIT))
     ((starts-with ii "@quit ") (QUIT (6 i)))
     ((= "@bye" ii)             (QUIT))
     ((= "@exit" ii)            (QUIT))
     ((= "@list" ii)            (CHANLIST))
     ((= "@names" ii)           (NAMES))
     ((starts-with ii "@names ") (NAMES (7 i)))
     ((starts-with ii "@raw ")  (send&print (5 i)))
     ((= "`" i)                 (set 'curuser ""))
     ((starts-with i "` ")      (DSAY (2 i)))
     ((starts-with i "`")       (regex "^([^ ]+) (.*)$" (1 i) 0) (set 'curuser $1) (DSAY $2))
     ((= "''" i)                (set 'curchan ""))
     ((= "'" i)                 (set 'lastpaged nil))
     ((starts-with i "''")      (QUERY (2 i)))
     ((starts-with i "' ")      (REPEATPAGE (2 i)))
     ((starts-with i "'")       (PAGE (1 i)))
     ((starts-with i ":")       (EMOTE (1 i)))
     (default                   (SAY i)))))

;; Receive data from the IRC server, log it, and display it in a friendly format.
(define (recv&print:recv&print)
  (unless partial (set 'partial ""))
  (let (buf "" stamp (string (date-value) " "))
    (unless (net-receive sock buf 4096)
      (println "newLisp recv error: " (net-error))
      (exit))
    (unless actualserver (set 'actualserver (1 (first (parse buf " ")))))
    (let (lines (clean empty? (parse (string partial buf) "\r|\n" 0)))
      (set 'partial (if (regex "(\r|\n)$" buf 0) "" (pop lines -1)))
      (dolist (l lines)
        (print-irc stamp l)
        (if logfd (write logfd (string stamp l "\n")))
        (when (regex "^PING :(.*)$" l 0) (PONG $1))))))

(set 'sock (net-connect server port)
     'input_buf ""
)

(if password
  (send&print "PASS " password))
(send&print "NICK " nick)
(send&print "USER " user " foo bar :" realname)

(while sock
  (while (net-select sock "read" 10000) ; 10 milliseconds
    (recv&print))
  ;; if we sent nothing to the server in the past 90 seconds,
  ;; send a PING to let it know we are still alive
  (when (< 90 (- (date-value) keepalive))
    (PING))
  (when (net-select sock "exception" 5000)
    (println "net-error: " (net-error))
    (close sock)
    (set 'sock nil))
  (while (< 0 (peek 0))
    (extend input_buf (char (read-char 0)))
    (when (= "\n" (input_buf -1))
      (pop input_buf -1)
      (translate_input input_buf)
      (set 'input_buf "")))
  (sleep 100)) ; sleep 1/10 of a second

(exit)
