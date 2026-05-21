use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'plain text lines', {
  it 'renders top-level plain text line', {
    expect(HAML.render(:src("Hello world\n"))).to.eq("Hello world\n");
  }

  it 'renders plain text as child of tag', {
    expect(HAML.render(:src("%p\n  Hello world\n"))).to.eq("<p>\n  Hello world\n</p>\n");
  }

  it 'backslash-escapes sigil', {
    expect(HAML.render(:src("\\%foo\n"))).to.eq("%foo\n");
  }

  it 'backslash-escapes .class shorthand', {
    expect(HAML.render(:src("\\.bar\n"))).to.eq(".bar\n");
  }

  it 'backslash-escapes #id shorthand', {
    expect(HAML.render(:src("\\#hash\n"))).to.eq("#hash\n");
  }

  it 'plain text inherits parent indent', {
    expect(HAML.render(:src("%div\n  Line 1\n  Line 2\n"))).to.eq("<div>\n  Line 1\n  Line 2\n</div>\n");
  }

  it 'deeply nested plain text', {
    expect(HAML.render(:src("%section\n  %p\n    Inner text\n"))).to.eq("<section>\n  <p>\n    Inner text\n  </p>\n</section>\n");
  }

  it 'renders plain text at indent 0', {
    expect(HAML.render(:src("Just text\n"))).to.eq("Just text\n");
  }

  it 'renders multiple plain lines as siblings', {
    expect(HAML.render(:src("plain1\nplain2\n"))).to.eq("plain1\nplain2\n");
  }

  it 'mixes tag and plain', {
    expect(HAML.render(:src("%p hello\nworld\n"))).to.eq("<p>hello</p>\nworld\n");
  }

  it 'inherits indent inside indented block', {
    expect(HAML.render(:src("%section\n  %div\n    indented plain\n"))).to.eq("<section>\n  <div>\n    indented plain\n  </div>\n</section>\n");
  }

  it 'strips trailing whitespace from plain', {
    expect(HAML.render(:src("Hello   \n"))).to.eq("Hello\n");
  }
}
