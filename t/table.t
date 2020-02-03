#!/usr/bin/env raku

use Test;
use Text::Diff;

# Tab escaping test
{
    my $result = diff(qq{TRAILING\t\n\tSTART\nMID\t\tDLE\n\tA\tL\tL\t}, q{}, output-style => 'Table');

    my $want = qq:to/_END_/;
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

done-testing

