use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

sub render(Str $src, *%args) { HAML.render(:$src, |%args) }

describe 'HAML preserve', {
  it 'pre tag preserves inner whitespace as &#x000A;', {
    expect(render("%pre\n  Line 1\n  Line 2\n"))
      .to.eq("<pre>&#x000A;  Line 1&#x000A;  Line 2&#x000A;</pre>\n");
  }

  it 'textarea preserves inner whitespace', {
    expect(render("%textarea\n  hello\n  world\n"))
      .to.eq("<textarea>&#x000A;  hello&#x000A;  world&#x000A;</textarea>\n");
  }

  it 'pre with single-line content unchanged', {
    expect(render("%pre Just text\n")).to.eq("<pre>Just text</pre>\n");
  }

  it 'pre nested in div preserves whitespace', {
    expect(render("%div\n  %pre\n    text\n"))
      .to.eq("<div>\n  <pre>&#x000A;    text&#x000A;  </pre>\n</div>\n");
  }

  it 'custom preserve element honored via config', {
    my $cfg = Template::HAML::Config.new(:preserve('custom-pre',));
    expect(render("%custom-pre\n  hi\n", :config($cfg)))
      .to.eq("<custom-pre>&#x000A;  hi&#x000A;</custom-pre>\n");
  }

  it 'pre not preserved when removed from preserve list', {
    my $cfg = Template::HAML::Config.new(:preserve('textarea',));
    expect(render("%pre\n  hi\n", :config($cfg)))
      .to.eq("<pre>\n  hi\n</pre>\n");
  }

  it '~ operator preserves newlines', {
    expect(render("~ \"line1\\nline2\"\n")).to.eq("line1&#x000A;line2\n");
  }

  it '~ operator with no newlines unchanged', {
    expect(render("~ 'no newlines here'\n")).to.eq("no newlines here\n");
  }

  it '~ operator inside a tag', {
    expect(render("%div\n  ~ \"a\\nb\"\n")).to.eq("<div>\n  a&#x000A;b\n</div>\n");
  }

  it '~ operator html-escapes by default', {
    expect(render("~ '<a>'\n")).to.eq("&lt;a&gt;\n");
  }
}
