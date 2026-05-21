use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

my $ITERS      = (%*ENV<HAML_BENCH_ITERS> // 5000).Int;
my $ast-cfg    = Template::HAML::Config.new(:emit<ast>);
my $direct-cfg = Template::HAML::Config.new(:emit<direct>);

my @cases = (
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

describe 'render benchmarks', :tag<benchmark>, {
  for @cases -> %c {
    it %c<name>, {
      my $src    = %c<src>;
      my %locals = %c<locals>;

      benchmark 'ast', :iterations($ITERS), :warmup(1), {
        HAML.render(:$src, :%locals, :config($ast-cfg));
      };

      benchmark 'direct', :iterations($ITERS), :warmup(1), {
        HAML.render(:$src, :%locals, :config($direct-cfg));
      };
    }
  }
}
