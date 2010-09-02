Adobe AIR SQLite Stress Tester
==============================

Why
---

I wrote this tool because I originally suspected there was something wrong with
Adobe AIR's SQLite implementation when under stress in an application I'm
writing.

Turns out that wasn't the case - the GC was collecting SQLStatement objects or
callbacks too early and so it wasn't able to notify the application that the
SQL statement had completed. That made it look like the application hung due to
the database.

Anyway, seeing as I had written it, I thought I might as well put it out there.
There isn't anything wrong with the AIR SQLite implementation as far as I know.

How
---

Install the AIR app, and run it. It has a functional GUI for changing the
various settings and seeing the results.

There isn't much code, and it is pretty self-explanatory. The one difficult part
would probably be the state machine - check the constructor of StressTestSM to
see the state table.

Then what?
----------

Not much really. The results should only be considered in terms of stress
testing. They are not very useful in terms of performance because the
application works using a state machine. The state machine switches states
based on a timer, therefore there is a delay between the SQL statement
finishing, and another starting again, as the machine switches through the
states until it comes back to that state. I guess that makes the results
comparable between machines.