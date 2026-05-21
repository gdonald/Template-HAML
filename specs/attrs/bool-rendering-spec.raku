use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'boolean attribute rendering', {
  it 'renders True as a bare attribute', {
    expect(HAML.render(:src(Q<%input{disabled: True}> ~ "\n")))
      .to.eq("<input disabled>\n");
  }

  it 'renders lowercase true as a bare attribute', {
    expect(HAML.render(:src(Q<%input{checked: true}> ~ "\n")))
      .to.eq("<input checked>\n");
  }

  it 'omits the attribute when value is False', {
    expect(HAML.render(:src(Q<%input{disabled: False}> ~ "\n")))
      .to.eq("<input>\n");
  }

  it 'omits False and keeps True in the same tag', {
    expect(HAML.render(:src(Q<%input{disabled: false, checked: True}> ~ "\n")))
      .to.eq("<input checked>\n");
  }

  it 'omits the attribute when value is Nil', {
    expect(HAML.render(:src(Q<%input{title: Nil}> ~ "\n")))
      .to.eq("<input>\n");
  }

  it 'renders an empty string value as an empty attribute', {
    expect(HAML.render(:src(Q<%input{title: ''}> ~ "\n")))
      .to.eq("<input title=''>\n");
  }
}
