use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML comments', {
  context 'HTML comments', {
    it 'renders single-line HTML comment', {
      expect(HAML.render(:src("/ Hello\n"))).to.eq("<!-- Hello -->\n");
    }

    it 'renders HTML comment with no text and no children', {
      expect(HAML.render(:src("/\n"))).to.eq("<!---->\n");
    }

    it 'wraps children in block HTML comment', {
      my $src = q:to/HAML/;
      /
        %p hi
      HAML
      expect(HAML.render(:src($src))).to.eq("<!--\n  <p>hi</p>\n-->\n");
    }

    it 'nests block comment with multiple children', {
      my $src = q:to/HAML/;
      %div
        /
          %p hi
          %p bye
      HAML
      expect(HAML.render(:src($src))).to.eq("<div>\n  <!--\n    <p>hi</p>\n    <p>bye</p>\n  -->\n</div>\n");
    }
  }

  context 'conditional comments', {
    it 'renders inline conditional comment', {
      expect(HAML.render(:src("/[if IE] text\n"))).to.eq("<!--[if IE]>text<![endif]-->\n");
    }

    it 'renders block conditional comment', {
      my $src = q:to/HAML/;
      /[if IE]
        %p ie only
      HAML
      expect(HAML.render(:src($src))).to.eq("<!--[if IE]>\n  <p>ie only</p>\n<![endif]-->\n");
    }

    it 'renders negated conditional', {
      expect(HAML.render(:src("/[if !IE] text\n"))).to.eq("<!--[if !IE]>text<![endif]-->\n");
    }

    it 'renders revealed conditional comment', {
      expect(HAML.render(:src("/![if !IE] text\n"))).to.eq("<!--[if !IE]><!-->text<!--<![endif]-->\n");
    }
  }

  context 'silent comments', {
    it 'silent comment produces no output', {
      expect(HAML.render(:src("-# silent\n"))).to.eq("");
    }

    it 'silent comment with indented body produces no output', {
      my $src = q:to/HAML/;
      -# silent
        some text
        more text
      HAML
      expect(HAML.render(:src($src))).to.eq("");
    }

    it 'silent comment between siblings does not interfere', {
      my $src = q:to/HAML/;
      %p hi
      -# this is a note
      %p bye
      HAML
      expect(HAML.render(:src($src))).to.eq("<p>hi</p>\n<p>bye</p>\n");
    }

    it 'silent comment body is opaque text, not parsed', {
      my $src = q:to/HAML/;
      %div
        -# notes:
          arbitrary text $^&* not valid HAML
          !!! also opaque
        %p hi
      HAML
      expect(HAML.render(:src($src))).to.eq("<div>\n  <p>hi</p>\n</div>\n");
    }

    it 'silent comment body may contain blank lines', {
      my $src = q:to/HAML/;
      -# header
        body line

        body line two
      HAML
      expect(HAML.render(:src($src))).to.eq("");
    }
  }
}
