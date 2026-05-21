use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML shorthand interpolation', {
  it '#{...} inside class shorthand', {
    expect(HAML.render(:src(Q[%div.item-#{$id}] ~ "\n"), :locals(%(id => 7))))
      .to.eq("<div class='item-7'></div>\n");
  }

  it 'class shorthand interp with content', {
    expect(HAML.render(:src(Q[%p.item-#{$id} Hello] ~ "\n"), :locals(%(id => 'x'))))
      .to.eq("<p class='item-x'>Hello</p>\n");
  }

  it 'class shorthand interp among static classes', {
    expect(HAML.render(:src(Q[%div.a.item-#{$id}.b] ~ "\n"), :locals(%(id => 3))))
      .to.eq("<div class='a item-3 b'></div>\n");
  }

  it '#{...} inside id shorthand', {
    expect(HAML.render(:src(Q[%div#row-#{$n}] ~ "\n"), :locals(%(n => 4))))
      .to.eq("<div id='row-4'></div>\n");
  }

  it 'id shorthand interp on explicit tag', {
    expect(HAML.render(:src(Q[%section#main-#{$slug}] ~ "\n"), :locals(%(slug => 'home'))))
      .to.eq("<section id='main-home'></section>\n");
  }

  it 'combined class and id shorthand interp', {
    expect(HAML.render(:src(Q[%li.item-#{$id}#row-#{$n}] ~ "\n"),
                       :locals(%(id => 'q', n => 2))))
      .to.eq("<li id='row-2' class='item-q'></li>\n");
  }

  it 'shorthand interp merges with hash class:', {
    expect(HAML.render(:src(Q[%p.item-#{$id}{class: 'active'}] ~ "\n"),
                       :locals(%(id => 9))))
      .to.eq("<p class='active item-9'></p>\n");
  }

  it 'shorthand id interp concatenates with hash id:', {
    expect(HAML.render(:src(Q[%p#row-#{$n}{id: 'extra'}] ~ "\n"),
                       :locals(%(n => 5))))
      .to.eq("<p id='row-5_extra'></p>\n");
  }

  it '\\#{...} in class shorthand is literal', {
    expect(HAML.render(:src(Q[%div.literal-\#{x}] ~ "\n")))
      .to.eq(Q[<div class='literal-#{x}'></div>] ~ "\n");
  }

  it '\\#{...} in id shorthand is literal', {
    expect(HAML.render(:src(Q[%div#row-\#{y}] ~ "\n")))
      .to.eq(Q[<div id='row-#{y}'></div>] ~ "\n");
  }

  it 'hyphenated class shorthand', {
    expect(HAML.render(:src("%p.foo-bar Hi\n"))).to.eq("<p class='foo-bar'>Hi</p>\n");
  }

  it 'hyphenated id shorthand', {
    expect(HAML.render(:src("%section#main-header\n")))
      .to.eq("<section id='main-header'></section>\n");
  }

  it '!{...} in class shorthand', {
    expect(HAML.render(:src(Q[%div.cls-!{$raw}] ~ "\n"), :locals(%(raw => 'X'))))
      .to.eq("<div class='cls-X'></div>\n");
  }

  it '#{...} in shorthand HTML-escapes the value', {
    expect(HAML.render(:src(Q[%div.item-#{$s}] ~ "\n"), :locals(%(s => 'a&b'))))
      .to.eq("<div class='item-a&amp;b'></div>\n");
  }

  it 'multiple interps in a single class shorthand', {
    expect(HAML.render(:src(Q[%div.a-#{$x}-b-#{$y}] ~ "\n"),
                       :locals(%(x => 1, y => 2))))
      .to.eq("<div class='a-1-b-2'></div>\n");
  }

  it 'static class then interp class', {
    expect(HAML.render(:src(Q[%div.x.item-#{$id}] ~ "\n"), :locals(%(id => 'k'))))
      .to.eq("<div class='x item-k'></div>\n");
  }

  it 'multiple interps in id shorthand', {
    expect(HAML.render(:src(Q[%div#r-#{$a}-#{$b}] ~ "\n"),
                       :locals(%(a => 'p', b => 'q'))))
      .to.eq("<div id='r-p-q'></div>\n");
  }

  it 'non-interp shorthand unchanged', {
    expect(HAML.render(:src("%a.cls#main go\n")))
      .to.eq("<a id='main' class='cls'>go</a>\n");
  }
}
