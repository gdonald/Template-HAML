#!/usr/bin/env raku

use v6.d;
use lib $*PROGRAM.parent.parent.parent.add('lib').Str;
use Template::HAML;

my $haml = HAML.new(:search-paths($*PROGRAM.parent.add('views').Str,));

my @posts = (
  %( :title<Hello, world>, :author<Greg>,
     :body("<p>This is the <em>first</em> post.</p>") ),
  %( :title<Second post>,  :author<Ada>,
     :body("<p>Another entry in the blog.</p>") ),
);

print $haml.render(
  :file<posts/index>,
  :layout<layouts/app>,
  :locals(%(
    :title<Example Blog>,
    :year(Date.today.year),
    :posts(@posts),
  )),
);
