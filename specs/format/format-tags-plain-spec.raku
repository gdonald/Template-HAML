use lib 'lib';
use BDD::Behave;
use Template::HAML::Format;

sub fmt(Str:D $src) { format-source($src) }

describe 'format-source: tags and plain text', {
  context 'bare and content tags', {
    it 'round-trips a bare tag', {
      expect(fmt("%p\n")).to.eq("%p\n");
    }

    it 'preserves a tag with content', {
      expect(fmt("%p hello\n")).to.eq("%p hello\n");
    }

    it 'collapses leading/trailing content whitespace', {
      expect(fmt("%p   hello   \n")).to.eq("%p hello\n");
    }
  }

  context 'nesting', {
    it 'uses 2-space indent on nested tags', {
      expect(fmt("%p\n  %strong inside\n")).to.eq("%p\n  %strong inside\n");
    }

    it 'preserves deep nesting', {
      expect(fmt("%section\n  %h1 Title\n  %ul\n    %li one\n    %li two\n")).to.eq(
        "%section\n  %h1 Title\n  %ul\n    %li one\n    %li two\n"
      );
    }

    it 'preserves inline content with a child', {
      expect(fmt("%p hello\n  %strong world\n")).to.eq(
        "%p hello\n  %strong world\n"
      );
    }
  }

  context 'void elements', {
    it 'emits void element without explicit /', {
      expect(fmt("%img\n")).to.eq("%img\n");
    }

    it 'drops explicit / on void element', {
      expect(fmt("%img/\n")).to.eq("%img\n");
    }

    it 'strips %br void self-close', {
      expect(fmt("%br/\n")).to.eq("%br\n");
    }

    it 'preserves explicit self-close on non-void element', {
      expect(fmt("%div/\n")).to.eq("%div/\n");
    }
  }

  context 'trim modifiers', {
    it 'preserves outer trim modifier', {
      expect(fmt('%p>' ~ "\n")).to.eq('%p>' ~ "\n");
    }

    it 'preserves inner trim modifier', {
      expect(fmt('%p<' ~ "\n")).to.eq('%p<' ~ "\n");
    }

    it 'preserves combined trim modifier', {
      expect(fmt('%p<>' ~ "\n")).to.eq('%p<>' ~ "\n");
    }

    it 'canonicalizes >< to <>', {
      expect(fmt('%p><' ~ "\n")).to.eq('%p<>' ~ "\n");
    }
  }

  context 'plain text', {
    it 'preserves top-level plain text', {
      expect(fmt("Hello world\n")).to.eq("Hello world\n");
    }

    it 'keeps backslash on plain text with leading %', {
      expect(fmt("\\%foo\n")).to.eq("\\%foo\n");
    }

    it 'keeps backslash on plain text with leading .', {
      expect(fmt("\\.bar\n")).to.eq("\\.bar\n");
    }

    it 'keeps backslash on plain text with leading #', {
      expect(fmt("\\#baz\n")).to.eq("\\#baz\n");
    }

    it 'preserves multiple plain siblings', {
      expect(fmt("plain1\nplain2\n")).to.eq("plain1\nplain2\n");
    }

    it 'preserves tag followed by plain sibling', {
      expect(fmt("%p hello\nworld\n")).to.eq("%p hello\nworld\n");
    }

    it 'preserves plain text as a child of a tag', {
      expect(fmt("%div\n  inside text\n")).to.eq("%div\n  inside text\n");
    }

    it 'strips trailing whitespace from plain text', {
      expect(fmt("Hello   \n")).to.eq("Hello\n");
    }
  }

  context 'normalization', {
    it 'normalizes CRLF and a leading blank line', {
      expect(fmt("\r\n%p hi\r\n")).to.eq("%p hi\n");
    }

    it 'collapses runs of blank lines to one', {
      expect(fmt("%p one\n\n\n%p two\n")).to.eq("%p one\n\n%p two\n");
    }

    it 'round-trips empty input', {
      expect(fmt("")).to.eq("");
    }
  }

  context 'idempotence', {
    it 'is idempotent on tag siblings', {
      expect(fmt("%p one\n%p two\n")).to.eq(fmt(fmt("%p one\n%p two\n")));
    }

    it 'is idempotent on a nested tree', {
      expect(fmt("%section\n  %h1 Title\n  %p hello\n    %em inside\n")).to.eq(
        fmt(fmt("%section\n  %h1 Title\n  %p hello\n    %em inside\n"))
      );
    }
  }
}
