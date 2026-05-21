use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::Helpers;

describe 'Template::HAML::Helpers', {
  context 'html-safe / SafeString', {
    it 'wraps a string in SafeString and preserves the raw text', {
      my $s = html-safe('<b>hi</b>');
      expect($s).to.be-a(Template::HAML::Helpers::SafeString);
      expect($s.Str).to.be('<b>hi</b>');
    }

    it 'passes a safe string through unescaped', {
      my $src = q:to/HAML/;
      %div
        = html-safe('<b>x</b>')
      HAML
      my $out = HAML.render(:src($src));
      expect($out).to.match(/'<b>x</b>'/);
      expect($out).to.not.match(/'&lt;'/);
    }
  }

  context 'html-safe with escape-html on (default)', {
    it 'still escapes plain strings', {
      my $src = q:to/HAML/;
      %p
        = '<b>plain</b>'
      HAML
      my $out = HAML.render(:src($src));
      expect($out).to.match(/'&lt;b&gt;plain&lt;/b&gt;'/);
    }
  }

  context 'escape-once', {
    it 'escapes plain angle brackets', {
      expect(escape-once('<b>')).to.be('&lt;b&gt;');
    }

    it 'preserves already-escaped entities', {
      expect(escape-once('&amp;')).to.be('&amp;');
      expect(escape-once('&#39;')).to.be('&#39;');
      expect(escape-once('&#x27;')).to.be('&#x27;');
    }

    it 'escapes bare ampersands', {
      expect(escape-once('& foo')).to.be('&amp; foo');
    }

    it 'mixes escape and preserve correctly', {
      expect(escape-once('&amp; & <')).to.be('&amp; &amp; &lt;');
    }
  }

  context 'surround / precede / succeed (Raku scope)', {
    it 'surround wraps the block result', {
      expect(surround('(', ')', { 'hi' })).to.be('(hi)');
    }

    it 'precede prepends to the block result', {
      expect(precede('* ', { 'hi' })).to.be('* hi');
    }

    it 'succeed appends to the block result', {
      expect(succeed('.', { 'hi' })).to.be('hi.');
    }

    it 'surround strips block whitespace', {
      expect(surround('<', '>', { "  hi  " })).to.be('<hi>');
    }
  }

  context 'surround in HAML template', {
    it 'appears in the rendered output', {
      my $src = q:to/HAML/;
      %p
        = surround('(', ')', { 'middle' })
      HAML
      my $out = HAML.render(:src($src));
      expect($out).to.match(/'(middle)'/);
    }
  }

  context 'list-of', {
    it 'wraps each item in an <li>', {
      my $out = list-of(<a b c>, -> $x { $x.uc });
      expect($out).to.be("<li>A</li>\n<li>B</li>\n<li>C</li>");
    }

    it 'works inside a HAML template', {
      my $src = q:to/HAML/;
      %ul
        != list-of($items, -> $x { $x.uc })
      HAML
      my $out = HAML.render(:src($src), :locals(%(items => <a b c>)));
      expect($out).to.match(/'<li>A</li>'/);
      expect($out).to.match(/'<li>B</li>'/);
      expect($out).to.match(/'<li>C</li>'/);
    }
  }

  context 'find-and-preserve', {
    it 'preserves newlines inside <pre>', {
      my $html = "<pre>line1\nline2</pre>";
      expect(find-and-preserve($html)).to.be('<pre>line1&#x000A;line2</pre>');
    }

    it 'preserves newlines inside <textarea>', {
      my $html2 = "<textarea>a\nb</textarea>";
      expect(find-and-preserve($html2)).to.be('<textarea>a&#x000A;b</textarea>');
    }

    it 'leaves non-preserve tags untouched', {
      my $html3 = "<div>\n  <p>hi</p>\n</div>";
      expect(find-and-preserve($html3)).to.be($html3);
    }

    it 'preserves attributes on preserved tags', {
      my $html4 = "<pre class='x'>a\nb</pre>";
      expect(find-and-preserve($html4)).to.be("<pre class='x'>a&#x000A;b</pre>");
    }
  }

  context 'capture-haml', {
    it 'renders the HAML source returned by the block', {
      my $out = capture-haml({ "%p hi" });
      expect($out).to.match(/'<p>hi</p>'/);
    }
  }

  context 'helpers visible inside embedded code', {
    it 'calls a helper from a = expression', {
      my $src = q:to/HAML/;
      %div
        != surround('[', ']', { 'inner' })
      HAML
      my $out = HAML.render(:src($src));
      expect($out).to.match(/'[inner]'/);
    }
  }
}
