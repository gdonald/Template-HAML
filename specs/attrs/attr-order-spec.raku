use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'attribute emission order', {
  it 'emits id and class first, then the rest in insertion order', {
    expect(HAML.render(:src(Q<%a{title: 't', class: 'c', id: 'i', href: '/'}> ~ "\n")))
      .to.eq("<a id='i' class='c' title='t' href='/'></a>\n");
  }

  it 'preserves insertion order for plain keys', {
    expect(HAML.render(:src(Q<%a{c: 3, a: 1, b: 2}> ~ "\n")))
      .to.eq("<a c='3' a='1' b='2'></a>\n");
  }

  it 'emits shorthand id first even with literal pairs after', {
    expect(HAML.render(:src(Q<%a#main{href: '/', class: 'cls'}> ~ "\n")))
      .to.eq("<a id='main' class='cls' href='/'></a>\n");
  }

  it 'emits shorthand class after id and before remaining keys', {
    expect(HAML.render(:src(Q<%a.foo{href: '/', id: 'm'}> ~ "\n")))
      .to.eq("<a id='m' class='foo' href='/'></a>\n");
  }
}
