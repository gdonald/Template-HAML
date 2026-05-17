#!/usr/bin/env -S raku -Ilib

# Bench harness comparing AST-walker vs direct-emit codegen.
#
# Usage (run from the project root):
#   bench/render.raku                       # default: 5000 iterations
#   bench/render.raku --iters=20000         # 20000 iterations

use v6.d;
use Template::HAML;
use Template::HAML::Config;

sub MAIN(Int :$iters = 5000) {
  my @cases = bench-cases();

  my $name-w = max(@cases.map(*<name>.chars));

  say "Iterations per case: $iters";
  say sprintf("%-{$name-w}s %12s %12s %12s %8s",
    '', 'AST (ms)', 'Direct (ms)', 'Δ (ms)', 'speedup');
  say '-' x ($name-w + 50);

  for @cases -> %c {
    my $src    = %c<src>;
    my %locals = %c<locals>;
    my $name   = %c<name>;

    my $ast-cfg    = Template::HAML::Config.new(:emit<ast>);
    my $direct-cfg = Template::HAML::Config.new(:emit<direct>);

    # Warm caches: first render for each path.
    HAML.render(:$src, :%locals, :config($ast-cfg));
    HAML.render(:$src, :%locals, :config($direct-cfg));

    my $ast-ms    = time-ms({ HAML.render(:$src, :%locals, :config($ast-cfg))   }, $iters);
    my $direct-ms = time-ms({ HAML.render(:$src, :%locals, :config($direct-cfg))}, $iters);

    my $delta   = $ast-ms - $direct-ms;
    my $speedup = $direct-ms > 0 ?? ($ast-ms / $direct-ms).round(0.01) !! Inf;

    say sprintf("%-{$name-w}s %12s %12s %+12s %7s×",
      $name,
      fmt-ms($ast-ms),
      fmt-ms($direct-ms),
      fmt-ms($delta),
      $speedup.Str);
  }
}

sub time-ms(&block, Int $iters --> Num) {
  my $start = now;
  block() for ^$iters;
  ((now - $start) * 1000).Num;
}

sub fmt-ms(Num() $ms --> Str) {
  sprintf('%.2f', $ms);
}

sub bench-cases {
  (
    {
      name   => 'static tags only',
      src    => Q:to/HAML/,
      %html
        %head
          %title Hello
        %body
          %h1 Welcome
          %p This is a paragraph.
          %p Another paragraph.
      HAML
      locals => %(),
    },
    {
      name   => 'inline expressions',
      src    => Q:to/HAML/,
      %h1= $title
      %p= $body
      %footer
        = $year ~ ' © ' ~ $author
      HAML
      locals => %(
        title  => 'Welcome',
        body   => 'Some content here',
        year   => 2026,
        author => 'gdonald',
      ),
    },
    {
      name   => 'for-loop over a list',
      src    => Q:to/HAML/,
      %ul
        - for $items -> $i
          %li= "item #{$i}"
      HAML
      locals => %(items => (1..50).list),
    },
    {
      name   => 'if/elsif/else chain',
      src    => Q:to/HAML/,
      - if $n < 10
        %p small
      - elsif $n < 100
        %p medium
      - elsif $n < 1000
        %p large
      - else
        %p huge
      HAML
      locals => %(n => 250),
    },
    {
      name   => 'dynamic attributes',
      src    => Q:to/HAML/,
      %a(href="/u/#{$id}" title="#{$title}")
        = $label
      HAML
      locals => %(id => 7, title => 'profile', label => 'View'),
    },
    {
      name   => 'attribute splat',
      src    => Q:to/HAML/,
      %a{|$attrs}= $label
      HAML
      locals => %(
        attrs => { href => '/x', class => 'btn primary' },
        label => 'Click',
      ),
    },
    {
      name   => 'filter (:plain) inside loop',
      src    => Q:to/HAML/,
      %div
        - for $items -> $i
          :plain
            row #{$i}
      HAML
      locals => %(items => (1..20).list),
    },
    {
      name   => 'mixed realistic template',
      src    => Q:to/HAML/,
      !!! 5
      %html
        %head
          %title= $title
        %body
          %header
            %h1= $title
          %main
            - for $posts -> $post
              %article
                %h2= $post<title>
                %p= $post<body>
                - if $post<tags>.elems
                  %ul.tags
                    - for $post<tags> -> $tag
                      %li.tag
                        = $tag
          %footer
            = "© #{$year}"
      HAML
      locals => %(
        title => 'Blog',
        year  => 2026,
        posts => (
          { title => 'First',  body => 'Hello',  tags => <a b c> },
          { title => 'Second', body => 'World',  tags => <b>     },
          { title => 'Third',  body => 'Foo',    tags => ()      },
        ),
      ),
    },
  );
}
