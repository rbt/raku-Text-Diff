# NAME

Text::Diff - Perform diffs on files and record sets

# SYNOPSIS

```raku
  use Text::Diff;

  # Mix and match filenames, strings, file handles, producer subs,
  # or arrays of records; returns diff in a string.
  # WARNING: can return B<large> diffs for large files.
  my $diff = diff $string1,   $string2, output-style => Context;
  my $diff = diff '/tmp/log1.txt'.IO.open, '/tmp/log2.txt'.IO.open;
  my $diff = diff @records1,  @records2;

  # May also mix input types:
  my $diff = diff @records1, $string2;
```

# DESCRIPTION

`diff()` provides a basic set of services akin to the GNU "diff"
utility. It is not anywhere near as feature complete as GNU "diff", but
it is better integrated with Perl and available on all platforms. It is
often faster than shelling out to a system's "diff" executable for small
files, and generally slower on larger files.

Relies on Algorithm::Diff for, well, the algorithm. This may not produce
the same exact diff as a system's local "diff" executable, but it will
be a valid diff and comprehensible by "patch".

```raku
diff($a, $b, Int :offset-a = 0, Int :offset-b = 0, Str :filename-a = 'A', Str :filename-b = 'B',
     Instant :mtime-a, Instant :mtime-b, OutputStyle :output-style = Unified, 
     Int :context-lines = 3 --> Str)
```

# OPTIONS

`diff()` takes two parameters from which to draw input and a set of
options to control it's output. The options are:

## context-lines
How many lines before and after each diff to display. Defaults to 3.

## filename-a, filename-b, mtime-a, mtime-b
The name of the file and the modification time "files"

These are filled in automatically for each file when diff() is
passed a filename, unless a defined value is passed in.

If a filename is not passed in and filename-a and filename-b are not
provided then "A" and "B" will be used as defaults.

## offset-a, offset-b
The index of the first line / element. These default to 1 for all
parameter types except ARRAY references, for which the default is 0.
This is because ARRAY references are presumed to be data structures,
while the others are line oriented text.

## output-style
`Unified`, `Context`, and `Table`.

Defaults to "Unified" (unlike standard "diff", but Unified is what's
most often used in submitting patches and is the most human readable
of the three.

`Table` presents a left-side/right-side comparison of the file contents.
This will not worth with patch but it is very human readable for thin
files.

```
      +--+----------------------------------+--+------------------------------+
      |  |../Test-Differences-0.2/MANIFEST  |  |../Test-Differences/MANIFEST  |
      |  |Thu Dec 13 15:38:49 2001          |  |Sat Dec 15 02:09:44 2001      |
      +--+----------------------------------+--+------------------------------+
      |  |                                  * 1|Changes                       *
      | 1|Differences.pm                    | 2|Differences.pm                |
      | 2|MANIFEST                          | 3|MANIFEST                      |
      |  |                                  * 4|MANIFEST.SKIP                 *
      | 3|Makefile.PL                       | 5|Makefile.PL                   |
      |  |                                  * 6|t/00escape.t                  *
      | 4|t/00flatten.t                     | 7|t/00flatten.t                 |
      | 5|t/01text_vs_data.t                | 8|t/01text_vs_data.t            |
      | 6|t/10test.t                        | 9|t/10test.t                    |
      +--+----------------------------------+--+------------------------------+
``
This format also goes to some pains to highlight "invisible" characters
on differing elements by selectively escaping whitespace:

```
      +--+--------------------------+--------------------------+
      |  |demo_ws_A.txt             |demo_ws_B.txt             |
      |  |Fri Dec 21 08:36:32 2001  |Fri Dec 21 08:36:50 2001  |
      +--+--------------------------+--------------------------+
      | 1|identical                 |identical                 |
      * 2|        spaced in         |        also spaced in    *
      * 3|embedded space            |embedded        tab       *
      | 4|identical                 |identical                 |
      * 5|        spaced in         |\ttabbed in               *
      * 6|trailing spaces\s\s\n     |trailing tabs\t\t\n       *
      | 7|identical                 |identical                 |
      * 8|lf line\n                 |crlf line\r\n             *
      * 9|embedded ws               |embedded\tws              *
      +--+--------------------------+--------------------------+
```

## LIMITATIONS
Since the module relies on Raku's internal line splitting which processes files as expected but
hides the details. Features such as notification about new-line at end-of-file, or differences
between \n and \r\n lines are not reported.

This module also does not (yet) provide advanced GNU diff features such as ignoring blank lines
or whitespace.

## AUTHOR

Adam Kennedy <adamk@cpan.org>

Barrie Slaymaker <barries@slaysys.com>

Ported from CPAN5 By: Rod Taylor <rbt@cpan.org>

## LICENSE

You can use and distribute this module under the terms of the The Artistic License 2.0. See the LICENSE file included in this distribution for complete details.
