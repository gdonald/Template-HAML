use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'attribute splat |$var', {
  it 'merges a hash of attributes into the tag', {
    my %attrs = href => '/about', title => 'About';
    expect(HAML.render(:src(Q[%a{|$attrs} link] ~ "\n"), :locals(%(attrs => %attrs))))
      .to.eq("<a href='/about' title='About'>link</a>\n");
  }

  it 'composes a splat with literal pairs', {
    my %attrs = title => 'Splatted';
    expect(HAML.render(
      :src(Q[%a{href: '/', |$attrs} go] ~ "\n"),
      :locals(%(attrs => %attrs))
    )).to.eq("<a href='/' title='Splatted'>go</a>\n");
  }

  it 'later splat overrides an earlier literal pair', {
    my %attrs = href => '/from-splat';
    expect(HAML.render(
      :src(Q[%a{href: '/from-literal', |$attrs} go] ~ "\n"),
      :locals(%(attrs => %attrs))
    )).to.eq("<a href='/from-splat'>go</a>\n");
  }

  it 'literal pair after splat overrides splat value', {
    my %attrs = href => '/from-splat';
    expect(HAML.render(
      :src(Q[%a{|$attrs, href: '/wins'} go] ~ "\n"),
      :locals(%(attrs => %attrs))
    )).to.eq("<a href='/wins'>go</a>\n");
  }

  it 'merges splat class with shorthand class', {
    my %h = class => 'b';
    expect(HAML.render(:src(Q[%div.a{|$h} hi] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<div class='b a'>hi</div>\n");
  }

  it 'merges splat class with shorthand and literal class', {
    my %h = class => 'c';
    expect(HAML.render(
      :src(Q[%div.a{class: 'b', |$h} hi] ~ "\n"),
      :locals(%(h => %h))
    )).to.eq("<div class='b c a'>hi</div>\n");
  }

  it 'concatenates splat id with shorthand id using underscore', {
    my %h = id => 'two';
    expect(HAML.render(:src(Q[%div#one{|$h}] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<div id='one_two'></div>\n");
  }

  it 'concatenates splat id with literal and shorthand id', {
    my %h = id => 'three';
    expect(HAML.render(
      :src(Q[%div#one{id: 'two', |$h}] ~ "\n"),
      :locals(%(h => %h))
    )).to.eq("<div id='one_two_three'></div>\n");
  }

  it 'lets later splat win while classes accumulate', {
    my %a = href => '/a', class => 'x';
    my %b = href => '/b', class => 'y';
    expect(HAML.render(
      :src(Q[%a{|$a, |$b} hi] ~ "\n"),
      :locals(%(a => %a, b => %b))
    )).to.eq("<a class='x y' href='/b'>hi</a>\n");
  }

  it 'accumulates ids across multiple splats with underscore', {
    my %a = id => 'one';
    my %b = id => 'two';
    expect(HAML.render(
      :src(Q[%div{|$a, |$b}] ~ "\n"),
      :locals(%(a => %a, b => %b))
    )).to.eq("<div id='one_two'></div>\n");
  }

  it 'supports boolean attributes via splat', {
    my %h = disabled => True, type => 'submit';
    expect(HAML.render(:src(Q[%input{|$h}/] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<input disabled type='submit'>\n");
  }

  it 'omits False attributes from a splat', {
    my %h = disabled => False, type => 'submit';
    expect(HAML.render(:src(Q[%input{|$h}/] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<input type='submit'>\n");
  }

  it 'merges a splat class array with shorthand class', {
    my %h = class => ['a', 'b'];
    expect(HAML.render(:src(Q[%div.zz{|$h} hi] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<div class='a b zz'>hi</div>\n");
  }

  it 'expands a splat data: hash to data-* attributes', {
    my %h = data => { id => 1, role => 'main' };
    expect(HAML.render(:src(Q[%a{|$h}] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<a data-id='1' data-role='main'></a>\n");
  }

  it 'treats an empty splat hash as a no-op', {
    my %h = ();
    expect(HAML.render(:src(Q[%a{|$h, href: '/'} link] ~ "\n"), :locals(%(h => %h))))
      .to.eq("<a href='/'>link</a>\n");
  }

  it 'splats the result of invoking a callable local', {
    my &mk = sub () { %( :href('/fn'), :title('fn') ) };
    expect(HAML.render(:src(Q[%a{|$mk()} link] ~ "\n"), :locals(%(mk => &mk))))
      .to.eq("<a href='/fn' title='fn'>link</a>\n");
  }

  it 'composes a splat with an interpolated literal value', {
    my %h = title => 'spat';
    expect(HAML.render(
      :src(Q[%a{href: "/u/#{$id}", |$h} go] ~ "\n"),
      :locals(%(id => 7, h => %h))
    )).to.eq("<a href='/u/7' title='spat'>go</a>\n");
  }

  it 'allows a splat inside a multi-line attribute hash', {
    my $src = q:to/HAML/;
    %a{
      href: '/',
      |$h
    } go
    HAML
    my %h = title => 'multiline';
    expect(HAML.render(:$src, :locals(%(h => %h))))
      .to.eq("<a href='/' title='multiline'>go</a>\n");
  }

  it 'lets a literal after the splat win in declaration order', {
    my %h = href => '/middle';
    expect(HAML.render(
      :src(Q[%a{href: '/first', |$h, href: '/last'} go] ~ "\n"),
      :locals(%(h => %h))
    )).to.eq("<a href='/last'>go</a>\n");
  }

  it 'splats a single Pair', {
    my $p = ('lang' => 'en');
    expect(HAML.render(:src(Q[%html{|$p}] ~ "\n"), :locals(%(p => $p))))
      .to.eq("<html lang='en'></html>\n");
  }

  it 'splats a list of Pairs', {
    my @pairs = ('lang' => 'en'), ('dir' => 'ltr');
    expect(HAML.render(:src(Q[%html{|$p}] ~ "\n"), :locals(%(p => @pairs))))
      .to.eq("<html lang='en' dir='ltr'></html>\n");
  }

  it 'HTML-escapes splatted attribute values', {
    my %h = title => q{he said "hi"};
    my $r = HAML.render(:src(Q[%a{|$h}] ~ "\n"), :locals(%(h => %h)));
    expect($r).to.include('&quot;hi&quot;');
  }
}
