use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML attribute values', {
  it 'bare number value', {
    expect(HAML.render(:src("%a\{tabindex: 1\}\n"))).to.eq("<a tabindex='1'></a>\n");
  }

  it 'negative number', {
    expect(HAML.render(:src("%a\{n: -3\}\n"))).to.eq("<a n='-3'></a>\n");
  }

  it 'decimal number', {
    expect(HAML.render(:src("%a\{x: 1.5\}\n"))).to.eq("<a x='1.5'></a>\n");
  }

  it 'array values for class join with space', {
    expect(HAML.render(:src("%a\{class: ['foo', 'bar']\}\n")))
      .to.eq("<a class='foo bar'></a>\n");
  }

  it 'array values for id join with underscore', {
    expect(HAML.render(:src("%a\{id: ['one', 'two']\}\n")))
      .to.eq("<a id='one_two'></a>\n");
  }

  it '\\n in double-quoted decodes to newline', {
    expect(HAML.render(:src("%a\{title: \"line\\nbreak\"\}\n")))
      .to.eq("<a title='line\nbreak'></a>\n");
  }

  it '\\\\ decodes to single backslash', {
    expect(HAML.render(:src("%a\{title: 'a\\\\b'\}\n")))
      .to.eq("<a title='a\\b'></a>\n");
  }
}
