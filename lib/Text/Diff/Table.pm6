use v6.d;

use Text::Diff::Output;

unit class Text::Diff::Table is Text::Diff::Base;

has $.offset-a = 0;
has $.offset-b = 0;
has $.index-label = 'Ln';

has @!elts = ();

sub escape(Str $string) {
    my $str = $string.trans( ["\a", "\b", "\e", "\f"] => ['\\a', '\\b', '\\e', '\\f'] );

    # Convert all non-printable characters to their Hex after \x
    $str = $str.subst(/ <-print> /, '\x' ~ *.ord.fmt('%02x'), :g);

    return $str;
}

# TODO: This was submitted to Text::Tabs. Use that module on merge?
# https://github.com/Altai-man/perl6-Text-Tabs/issues/new
sub expand-tabs(Str $string, :$tab-stop = 4) {
    my $expanded = q{};
    my $position = 0;
    for $string.split(/\t/, :v) -> $part {
        if ($part eq "\t") {
            my $distance-from-stop = ($position) % $tab-stop;
            my $tab-length = $tab-stop - $distance-from-stop;
            $expanded ~= q{ } x $tab-length;
            $position += $tab-length;
        } else {
            $position += $part.chars;
            $expanded ~= $part;
        }
    }

    return $expanded;
}

my $missing-elt = [ "", "" ];

method hunk ($a, $b, @ops) {
    my ( @A, @B );
    for @ops -> $op {
        my $opcode = $op.opcode;
        if ( $opcode eq " " ) {
            @A.push($missing-elt) while @A < @B;
            @B.push($missing-elt) while @B < @A;
        }

        # Convert to lines
        @A.push([ $op.a-linenum + $.offset-a, $a.lines[$op.a-linenum] ])
                if $opcode eq " " || $opcode eq q{-};
        @B.push([ $op.b-linenum + $.offset-b, $b.lines[$op.b-linenum] ])
                if $opcode eq " " || $opcode eq q{+};
    }

    @A.push($missing-elt) while @A < @B;
    @B.push($missing-elt) while @B < @A;
    my @elts;
    for ^@A.elems - 1 {
        my $A = @A.shift;
        my $B = @B.shift;

        # Do minimal cleaning on identical elts so these look "normal":
        # tabs are expanded, trailing newelts removed, etc.  For differing
        # elts, make invisible characters visible if the invisible characters
        # differ.
        my $elt_type =  $B eq $missing-elt ?? "A" !!
                $A eq $missing-elt ?? "B" !!
                $A[1] eq $B[1]  ?? "="
                !! "*";
        if ( $elt_type ne "*" ) {
            if ( $elt_type eq "=" || $A[1] ~~ /\S/ || $B[1] ~~ /\S/ ) {
                $A[1] = escape expand-tabs $A[1];
                $B[1] = escape expand-tabs $B[1];
            } else {
                $A[1] = escape $A[1];
                $B[1] = escape $B[1];
            }
        } else {
            $A[1] ~~ /^(\s*)? (.*\S)? (\s*)?$/;
            my ( $l-ws-A, $body-A, $t-ws-A ) = ($1 // q{}, $2 // q{}, $3 // q{});
            $B[1] ~~ /^(\s*)? (.*\S)? (\s*)?$/;
            my ( $l-ws-B, $body-B, $t-ws-B ) = ($1 // q{}, $2 // q{}, $3 // q{});

            my $added-escapes;
            if ($l-ws-A ne $l-ws-B ) {
                # Make leading tabs visible.  Other non-' ' chars
                # will be dealt with in escape(), but this prevents
                # tab expansion from hiding tabs by making them
                # look like ' '.
                $l-ws-A ~~ s/<[\t]>/\\t/;
                $l-ws-B ~~ s/<[\t]>/\\t/;
            }

            if ( $t-ws-A ne $t-ws-B ) {
                # Only trailing whitespace gets the \s treatment
                # to make it obvious what's going on.
                $t-ws-A ~~ s/" "/\\s/;
                $t-ws-B ~~ s/" "/\\s/;
                $t-ws-A ~~ s/<[\t]>/\\t/;
                $t-ws-B ~~ s/<[\t]>/\\t/;
            }
            else {
                $t-ws-A = $t-ws-B = q{};
            }

            if ($body-A ne $body-B) {
                $t-ws-A ~~ s/" "/\\s/;
                $t-ws-B ~~ s/" "/\\s/;
                $t-ws-A ~~ s/<[\t]>/\\t/;
                $t-ws-B ~~ s/<[\t]>/\\t/;
            }

            my $line-A = ($l-ws-A, $body-A, $t-ws-A).join(q{});
            my $line-B = ($l-ws-B, $body-B, $t-ws-B).join(q{});

            $A[1] = escape $line-A;
            $B[1] = escape $line-B;
        }

        @elts.push([ |@$A, |@$B, $elt_type ]);
    }

    @!elts.append(@elts);
    @!elts.append(['bar']);

    # All output work is done as part of file-footer. Return an empty string for diff append.
    return q{};
}

method file-footer($a, $b) {
    my @seqs = ($a, $b);

    my @heading-lines;
    # Pushes out a sequence instead of an array row
    if ( $a.name.defined || $b.name.defined ) {
        @heading-lines.push([ '',
        escape( $a.name.defined ?? $a.name !! '<Nil>' ),
        '',
        escape( $b.name.defined ?? $b.name !! '<Nil>' ),
        '=',
        ]);
    }

    if ( $a.mtime.defined || $b.mtime.defined ) {
        @heading-lines.push(['',
        $a.mtime.defined ??  $a.mtime.to-posix[0]  !! '',
        '',
        $b.mtime.defined ??  $b.mtime.to-posix[0]  !! '',
        '=',
        ]);
    }

    if ( $.index-label ) {
        @heading-lines.push([ "", "", "", "", "=" ]) unless @heading-lines;
        @heading-lines[*-1][0] = @heading-lines[*-1][2] = $.index-label;
    }

    # TODO: This was a comment on the Perl5 process. Does it apply to Raku as well?
    # Not ushifting on to @!elts in case it's really big.  Want
    # to avoid the overhead.

    my $four-column-mode = False;

    for ( |@heading-lines, |@!elts ) -> $cols {
        next if $cols[*-1] eq 'bar';
        if ( $cols.elems > 2 and $cols[0] ne $cols[2] ) {
            $four-column-mode = True;
            last;
        }
    }

    if not $four-column-mode {
        for ( |@heading-lines, |@!elts ) -> $cols {
            next if $cols[*-1] eq 'bar';
            $cols.splice(2, 1);
        }
    }

    my @w = (0,0,0,0);
    for ( |@heading-lines, |@!elts ) -> $cols {
        next if $cols[*-1] eq 'bar';
        for 0..($cols.elems - 2) -> $i {
            @w[$i] = $cols[$i].chars
                    if $cols[$i].defined && $cols[$i].chars > @w[$i];
        }
    }

    my %fmts = $four-column-mode
            ?? ( "=" => "| %{@w[0]}s|%-{@w[1]}s  | %{@w[2]}s|%-{@w[3]}s  |\n",
                 "A" => "* %{@w[0]}s|%-{@w[1]}s  * %{@w[2]}s|%-{@w[3]}s  |\n",
                 "B" => "| %{@w[0]}s|%-{@w[1]}s  * %{@w[2]}s|%-{@w[3]}s  *\n",
                 "*" => "* %{@w[0]}s|%-{@w[1]}s  * %{@w[2]}s|%-{@w[3]}s  *\n",
               )
            !! ( "=" => "| %{@w[0]}s|%-{@w[1]}s  |%-{@w[2]}s  |\n",
                 "A" => "* %{@w[0]}s|%-{@w[1]}s  |%-{@w[2]}s  |\n",
                 "B" => "| %{@w[0]}s|%-{@w[1]}s  |%-{@w[2]}s  *\n",
                 "*" => "* %{@w[0]}s|%-{@w[1]}s  |%-{@w[2]}s  *\n",
    );

    my @args = ('', '', '');
    @args.push('') if $four-column-mode;
    %fmts<bar> = %fmts{'='}.sprintf(|@args);
    %fmts<bar> ~~ s:g/\S/+/;
    %fmts<bar> ~~ s:g/" "/-/;

    my @fmt-set = ( ['bar'] );
    @fmt-set.append(@heading-lines);
    @fmt-set.append(['bar']) if @heading-lines.elems > 0;
    @fmt-set.append(@!elts);

    my @table-lines = @fmt-set.map(-> $line { %fmts{$line[*-1]}.sprintf( $line[0 .. *-2] ) });

    return @table-lines.join(q{});
}

#`[[
=begin pod

=head1 NAME

  Text::Diff::Table - Text::Diff plugin to generate "table" format output

=head1 SYNOPSIS

  use Text::Diff;

  diff \@a, $b, { STYLE => "Table" };

=head1 DESCRIPTION

This is a plugin output formatter for Text::Diff that generates "table" style
diffs:

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

This format also goes to some pains to highlight "invisible" characters on
differing elements by selectively escaping whitespace.  Each element is split
in to three segments (leading whitespace, body, trailing whitespace).  If
whitespace differs in a segement, that segment is whitespace escaped.

Here is an example of the selective whitespace.

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

Here's why the lines do or do not have whitespace escaped:

=over

=item lines 1, 4, 7 don't differ, no need.

=item lines 2, 3 differ in non-whitespace, no need.

=item lines 5, 6, 8, 9 all have subtle ws changes.

=back

Whether or not line 3 should have that tab character escaped is a judgement
call; so far I'm choosing not to.

=head1 UNICODE

To output the raw unicode chracters consult the documentation of
L<Text::Diff::Config>. You can set the C<DIFF_OUTPUT_UNICODE> environment
variable to 1 to output it from the command line. For more information,
consult this bug: L<https://rt.cpan.org/Ticket/Display.html?id=54214> .

=head1 LIMITATIONS

Table formatting requires buffering the entire diff in memory in order to
calculate column widths.  This format should only be used for smaller
diffs.

Assumes tab stops every 8 characters, as $DIETY intended.

Assumes all character codes >= 127 need to be escaped as hex codes, ie that the
user's terminal is ASCII, and not even "high bit ASCII", capable.  This can be
made an option when the need arises.

Assumes that control codes (character codes 0..31) that don't have slash-letter
escapes ("\n", "\r", etc) in Perl are best presented as hex escapes ("\x01")
instead of octal ("\001") or control-code ("\cA") escapes.

=head1 AUTHOR

Barrie Slaymaker E<lt>barries@slaysys.comE<gt>

=head1 LICENSE

Copyright 2001 Barrie Slaymaker, All Rights Reserved.

You may use this software under the terms of the GNU public license, any
version, or the Artistic license.

=end pod
]]
