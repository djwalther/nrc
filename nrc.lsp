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

(define (send&print)
  (let (buf (string (apply string (args)) "\n") stamp (string (date-value) " "))
    (print stamp buf)
    (if logfd (write logfd (string stamp buf)))
    (unless (net-send sock buf)
      (println "newLisp send error: " (net-error))
      (exit)))
    (set 'keepalive (date-value)))

(define (PONG msg)  (send&print "PONG :" msg))
(define (PING)      (send&print "PING :" actualserver))
(define (QUIT)      (send&print "QUIT" (if (args) (string " :" (apply string (args))) "")) (exit))
(define (JOIN chan) (send&print "JOIN " chan) (set 'curchan chan))
(define (PART chan) (if (starts-with chan "#") (send&print "PART " chan)) (set 'curchan ""))
(define (SAY msg)   (send&print "PRIVMSG " curchan " :" msg))
(define (DSAY msg)  (send&print "PRIVMSG " curchan " :" curuser ": " msg))
(define (QUERY msg) (regex "^([^ ]+) (.*)$" msg) (set 'curchan $1) (SAY $2))
(define (EMOTE msg) (send&print "PRIVMSG " curchan " :ACTION " msg ""))
(define (LIST)      (send&print "LIST"))

;; translates text input from the keyboard, into actual IRC commands
(define (translate_input)
  (letn (i (apply string (args)) ii (lower-case i))
    (cond
     ((empty? i) nil) ; do nothing
     ((= "##" i)                (PART curchan))
     ((starts-with ii "#")      (JOIN i))
     ((= "@quit" ii)            (QUIT))
     ((starts-with ii "@quit ") (QUIT (6 i)))
     ((= "@bye" ii)             (QUIT))
     ((= "@exit" ii)            (QUIT))
     ((= "@list" ii)            (LIST))
     ((starts-with ii "@raw ")  (send&print (5 i)))
     ((= "`" i)                 (set 'curuser ""))
     ((starts-with i "` ")      (DSAY (2 i)))
     ((starts-with i "`")       (regex "^([^ ]+) (.*)$" (1 i)) (set 'curuser $1) (DSAY $2))
     ((= "'" i)                 (set 'curchan ""))
     ((starts-with i "'")       (QUERY (1 i)))
     ((starts-with i ":")       (EMOTE (1 i)))
     (default                   (SAY i)))))

(define (recv&print:recv&print)
  (unless partial (set 'partial ""))
  (let (buf "" stamp (string (date-value) " "))
    (unless (net-receive sock buf 4096)
      (println "newLisp recv error: " (net-error))
      (exit))
    (unless actualserver (set 'actualserver (first (parse buf " "))))
    (let (lines (clean empty? (parse (string partial buf) "\r|\n" 0)))
      (set 'partial (if (regex "\r|\n" (buf -1)) "" (pop lines -1)))
      (dolist (l lines)
        (println stamp l)
        (if logfd (write logfd (string stamp l "\n")))
        (when (regex {^PING :(.*)$} l) (PONG $1))))))

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
