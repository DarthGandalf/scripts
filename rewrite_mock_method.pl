#!/usr/bin/perl -i

# Rewrites code like this:
#
#     MOCK_METHOD1(Bar, double(std::string s));
#
# to this:
#
#     MOCK_METHOD(double, Bar, (std::string s), (override));
#
# If the method doesn't actually override and therefore doesn't compile
# anymore, you need to take a closer look. It might indicate a dead code, or a
# bug where the method in the base class has a different signature. Also you
# can remove the added (override).
#
# Usage: ./rewrite_mock_method.pl path/to/file.h

use strict;
use warnings;

# Matches nested () and <>. This is $RE{balanced}{-parens => "()<>"} from
# Regexp::Common::balanced but without dependency on Regexp::Common itself.
my $parentheses = qr/(?^:((?:\((?:(?>[^\(\)]+)|(?-1))*\))|(?:\<(?:(?>[^\<\>]+)|(?-1))*\>)))/;
# The same but only for ()
my $parentheses2 = qr/(?^:((?:\((?:(?>[^\(\)]+)|(?-1))*\))))/;

# Returns either the parameter, or parameter in () if it contains commas
sub comma_parentheses {
	my $s = shift;
	# Only commas outside () matter.
	my $simplified = $s;
	$simplified =~ s/$parentheses2//g;
	if ($simplified =~ /,/) {
		"($s)"
	} else {
		$s
	}
}

# Read the whole file
local $/;
my $file = <>;

$file =~ s/
	MOCK(_CONST)?_METHOD\d+(?:_T)?(_WITH_CALLTYPE)?  # old macro
	\(\s*
	(?(2)([^,]+),\s*)  # call type
	(\w+),  # name of method
	\s*
	((?:$parentheses|[^(])+?)  # return type
	\(((?:.(?!\)\s*;))*)\)  # parameters which are captured without outer ()
	\s*\)\s*;
/
	# Save values of $1... because the nested regexes will overwrite them.
	# $2 is used only in (?(2)) above.
	# $6 is skipped because it's an implementation detail of $parentheses.
	my ($const, $calltype, $name, $return, $args) = ($1, $3, $4, $5, $7);
	$return = comma_parentheses($return);

	# Surround every parameter with () if necessary.
	$args =~ s\/((?:$parentheses|[^,])+)\/comma_parentheses($1)\/sge;

	my @qualifiers;
	push @qualifiers, 'const' if $const;
	push @qualifiers, 'override';
	push @qualifiers, "Calltype($calltype)" if $calltype;
	my $qualifiers = join ', ', @qualifiers;

	"MOCK_METHOD($return, $name, ($args), ($qualifiers));"
/sgex;

print $file;
