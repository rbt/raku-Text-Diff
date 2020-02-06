#!/usr/bin/perl

use Test;
use Text::Diff;
use Algorithm::Diff :traverse_sequences;

class DiffTest {
    has %.options is required;
    has Str $.want is required;
    has Str $.test-name is required;

    # For documentation purposes at the moment
    # An advanced use would compare against actual qx{diff} output
    has Str $.gnu-diff-flags;

    has $.FILENAME_A = "A";
    has Instant $.MTIME_A .= from-posix(1007983243);
    has $.FILENAME_B = "B";
    has Instant $.MTIME_B .= from-posix(1007983244);

    has Str $.A = <1 2 3 4 5d 6 7 8 9    10 11 11d 12 13>.join("\n") ~ "\n";
    has Str $.B = <1 2 3 4 5a 6 7 8 9 9a 10 11     12 13>.join("\n") ~ "\n";

    method run() {
        my $result = diff($.A, $.B, column-a-name => $.FILENAME_A, column-b-name => $.FILENAME_B, mtime-a => $.MTIME_A, mtime-b => $.MTIME_B, |%.options);
        is $result, $.want, $.test-name;
    }
}

DiffTest.new(gnu-diff-flags => '-u', options => (), want => q:to/_TEST_/, test-name => 'Unified, no options').run();
--- A	1007983243
+++ B	1007983244
@@ -2,13 +2,13 @@
 2
 3
 4
-5d
+5a
 6
 7
 8
 9
+9a
 10
 11
-11d
 12
 13
_TEST_

DiffTest.new(gnu-diff-flags => '-c', options => (output-style => 'Context'), want => q:to/_TEST_/, test-name => 'Context, no options').run();
*** A	1007983243
--- B	1007983244
***************
*** 2,13 ****
  2
  3
  4
! 5d
  6
  7
  8
  9
  10
  11
- 11d
  12
  13
--- 2,13 ----
  2
  3
  4
! 5a
  6
  7
  8
  9
+ 9a
  10
  11
  12
  13
_TEST_


DiffTest.new(gnu-diff-flags => '-C0', options => (output-style => 'Context', context-lines => 0), want => q:to/_TEST_/, test-name => 'Context, no context lines').run();
*** A	1007983243
--- B	1007983244
***************
*** 5 ****
! 5d
--- 5 ----
! 5a
***************
*** 9 ****
--- 10 ----
+ 9a
***************
*** 12 ****
- 11d
--- 12 ----
_TEST_

DiffTest.new(gnu-diff-flags => '-C0', options => (output-style => 'Unified', context-lines => 0), want => q:to/_TEST_/, test-name => 'Unified, no context lines').run();
--- A	1007983243
+++ B	1007983244
@@ -5 +5 @@
-5d
+5a
@@ -9,0 +10 @@
+9a
@@ -12 +12,0 @@
-11d
_TEST_

DiffTest.new(options => (output-style => 'Table', context-lines => 1), want => q:to/_TEST_/, test-name => 'Table, 1 context line').run();
+---+------------+---+------------+
|   |A           |   |B           |
| Ln|1007983243  | Ln|1007983244  |
+---+------------+---+------------+
|  3|4           |  3|4           |
*  4|5d          *  4|5a          *
|  5|6           |  5|6           |
+---+------------+---+------------+
|  8|9           |  8|9           |
|   |            *  9|9a          *
|  9|10          | 10|10          |
| 10|11          | 11|11          |
* 11|11d         *   |            |
| 12|12          | 12|12          |
| 13|13          | 13|13          |
+---+------------+---+------------+
_TEST_

done-testing;
