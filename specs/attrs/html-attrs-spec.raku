use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML HTML-style attributes', {
  it 'HTML-style single-quoted value', {
    expect(HAML.render(:src(Q[%a(href='/')] ~ "\n"))).to.eq("<a href='/'></a>\n");
  }

  it 'HTML-style double-quoted value', {
    expect(HAML.render(:src(Q[%a(href="/")] ~ "\n"))).to.eq("<a href='/'></a>\n");
  }

  it 'bool attr (no value) renders bare in HTML5', {
    expect(HAML.render(:src(Q[%input(disabled)] ~ "\n"))).to.eq("<input disabled>\n");
  }

  it 'combine ()-attrs and {}-attrs', {
    expect(HAML.render(:src(Q<%a(href='/'){title: 'home'}> ~ "\n")))
      .to.eq("<a href='/' title='home'></a>\n");
  }

  it 'multiple HTML attrs in parens', {
    expect(HAML.render(:src(Q[%a(href='/' title='home')] ~ "\n")))
      .to.eq("<a href='/' title='home'></a>\n");
  }

  it 'hyphenated HTML attr name', {
    expect(HAML.render(:src(Q[%a(data-id='42')] ~ "\n")))
      .to.eq("<a data-id='42'></a>\n");
  }
}
