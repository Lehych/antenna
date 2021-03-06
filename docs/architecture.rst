============
Architecture
============

Purpose
=======

Antenna handles incoming breakpad crash reports and saves them to AWS S3.


Requirements
============

Antenna is built with the following requirements:

1. **Return a crash id to the client quickly**

   Antenna should return a crash id and close the HTTP connection as quickly as
   possible. This means we need to save to AWS S3 as a separate step.

2. **Try hard not to drop crashes**

   Antenna tries hard not to drop crashes and lose data. It tries to get the
   crash to AWS S3 as quickly as possible so that it's sitting on as few crash
   reports as possible.

3. **Minimal dependencies**

   Every dependency we add is another software cycle we have to track causing us
   to have to update our code when they change.

4. **Make setting it up straight-forward**

   Antenna should be straight-forward to set up. Minimal configuration options.
   Solid documentation.

5. **Easy to test**

   Antenna should be built in such a way that it's easy to write tests for.
   Tests that are easy to read and easy to write are easy to verify and this
   will make it likely that the software is higher quality.


High-level architecture
=======================

.. graphviz::

   digraph G {
       edge [
           fontsize=9
       ];
       node [
           shape=box,
           fontsize=9
       ];

       rankdir=LR;

       subgraph clusternode {
           rank=same;

           nginx [shape=box, label="nginx", height=1];
           antenna [shape=box, label="Gunicorn\nrunning\nAntenna", height=1];
       }

       client [shape=box3d, label="Breakpad\nclient"];
       awss3 [shape=tab, label="AWS S3"];

       client -> nginx [label="HTTP POST"];

       nginx -> antenna;
       antenna -> nginx;

       nginx -> client [label="crashid"];
       antenna -> awss3 [label="save to S3"];

       { rank=min; client; }
       { rank=max; awss3; }
   }


We run multiple Antenna nodes behind an ELB.


Data flow
=========

This is the rough data flow:

1. Breakpad client submits a crash report via HTTP POST with a
   multipart/form-data encoded payload.

2. Antenna's ``BreakpadSubmitterResource`` handles the HTTP POST
   request.

   If the payload is compressed, it uncompresses it.

   It extracts the payload converting it into a dict.

   It throttles the crash.

   It generates a crash id.

   It returns the crash id to the breakpad client.

3. The ``BreakpadSubmitterResource`` tosses the crash in the ``crashmover_save_queue``.
   It tosses the crash in the ``crashmover_save_queue``.

4. At this point, the HTTP conversation is done and the connection ends.

5. ... time passes depending on how many things are in the
   ``crashmover_save_queue``.

6. A crashmover coroutine frees up, pulls the crash out of the
   ``crashmover_save_queue``, and then tries to save it to whatever crashstorage
   class is set up. If it's :everett:comp:`S3CrashStorage`, then it saves it to
   AWS S3.

   If the save is successful, then the coroutine moves on to the next crash in
   the queue.

   If the save is not successful, the coroutine puts the crash back in the queue
   and moves on with the next crash.


Diagnostics
===========

Logs to stdout
--------------

Antenna logs its activity to stdout.

Logs have the following format:

    [TIMESTAMP] [ANTENNA HOST] [LOGLEVEL] name: message


You can see crashes being accepted and saved::

    [2017-03-14 14:58:09 +0000] [ANTENNA ip-172-31-25-230 11] [INFO] antenna.breakpad_resource: 1ad900ab-58f6-401a-b6e1-a606d1170314: matched by is_firefox_desktop; returned DEFER
    [2017-03-14 14:58:09 +0000] [ANTENNA ip-172-31-25-230 11] [INFO] antenna.breakpad_resource: 1ad900ab-58f6-401a-b6e1-a606d1170314 saved


You can see the heartbeat kicking off::

    [2017-03-14 14:58:07 +0000] [ANTENNA ip-172-31-25-230 10] [DEBUG] antenna.heartbeat: thump


Statsd
------

Antenna sends data to statsd. Read the code for what's available where and what
it means.

Here are some good ones:

* ``breakpad_resource.incoming_crash``

  Counter. Denotes an incoming crash.

* ``throttle.*``

  Counters. Throttle results. Possibilities: ``accept``, ``defer``, ``reject``.

* ``breakpad_resource.save_crash.count``

  Counter. Denotes a crash has been successfully saved.

* ``breakpad_resource.save_queue_size``

  Gauge. Tells you how many things are sitting in the ``crashmover_save_queue``.

  .. Note::

     If this number is > 0, it means that Antenna is having difficulties keeping
     up with incoming crashes.

* ``breakpad_resource.on_post.time``

  Timing. This is the time it took to handle the HTTP POST request.

* ``breakpad_resource.crash_save.time``

  Timing. This is the time it took to save the crash to S3.

* ``breakpad_resource.crash_handling.time``

  Timing. This is the total time the crash was in Antenna-land from receiving
  the crash to saving it to S3.


Sentry
------

Antenna works with `Sentry <https://sentry.io/welcome/>`_ and will send
unhandled startup errors and other unhandled errors to Sentry where you can more
easily see what's going on. You can use the hosted Sentry or run your own Sentry
instance--either will work fine.
