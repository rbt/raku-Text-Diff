#!/usr/bin/env raku

use Test;
use Text::Diff;

# Tab escaping test
{
    my $result = diff(qq{TRAILING\t\n\tSTART\nMID\t\tDLE\n\tA\tL\tL\t}, q{}, output-style => 'Table');

    my $want = q:to/_END_/;
+---+------------------+---+---+
| Ln|A                 | Ln|B  |
+---+------------------+---+---+
*  0|TRAILING          *   |   |
*  1|    START         *   |   |
*  2|MID     DLE       *   |   |
*  3|    A   L   L     *   |   |
+---+------------------+---+---+
_END_
    is $result, $want, 'Tab formatting';
}

# Keep leading spacing during body mismatch
{
    my $result = diff(qq{\tLine 1\n  \tLine 2 has a\t problem  \n\tLine 3}, qq{\tLine 1\n  \tLine 2 is a problem   \n\tLine 3}, output-style => 'Table');

    my $want = q:to/_END_/;
+---+--------------------------------+-------------------------------+
| Ln|A                               |B                              |
+---+--------------------------------+-------------------------------+
|  0|    Line 1                      |    Line 1                     |
*  1|    Line 2 has a\t problem\s\s  |    Line 2 is a problem\s\s\s  *
|  2|    Line 3                      |    Line 3                     |
+---+--------------------------------+-------------------------------+
_END_

    is $result, $want, 'Tab formatting';
}

done-testing

