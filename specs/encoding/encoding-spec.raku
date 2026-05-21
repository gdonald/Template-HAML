use lib 'lib', 'specs/lib';
use BDD::Behave;
use SpecHelpers;
use Template::HAML;
use Template::HAML::Config;
use Template::HAML::X;

describe 'encoding', {
  context 'Config encoding canonicalization', {
    it 'accepts utf-8 verbatim', {
      my $cfg = Template::HAML::Config.new(:encoding<utf-8>);
      expect($cfg.encoding).to.be('utf-8');
    }

    it 'canonicalizes common aliases', {
      expect(Template::HAML::Config.new(:encoding<UTF8>).encoding).to.be('utf-8');
      expect(Template::HAML::Config.new(:encoding<latin1>).encoding).to.be('iso-8859-1');
      expect(Template::HAML::Config.new(:encoding<US-ASCII>).encoding).to.be('ascii');
      expect(Template::HAML::Config.new(:encoding<cp1252>).encoding).to.be('windows-1252');
    }

    it 'dies on unknown encoding name and names the bad value', {
      expect({ Template::HAML::Config.new(:encoding<klingon>) }).to.raise-error;
      my $e = catch-it({ Template::HAML::Config.new(:encoding<klingon>) });
      expect($e.message).to.include('klingon');
    }
  }

  context 'BOM handling', {
    it 'strips a BOM at the start of a Str source', {
      my $src = "\x[FEFF]" ~ "%p hi\n";
      expect(HAML.render(:$src)).to.eq("<p>hi</p>\n");
    }

    it 'strips a UTF-8 BOM in a Blob source', {
      my Blob $src = Buf.new(0xEF, 0xBB, 0xBF) ~ "%p hi\n".encode('utf-8');
      expect(HAML.render(:$src)).to.eq("<p>hi</p>\n");
    }
  }

  context 'Blob decoding', {
    it 'decodes utf-8 Blob source', {
      my Blob $src = "%p café\n".encode('utf-8');
      expect(HAML.render(:$src)).to.eq("<p>café</p>\n");
    }

    it 'decodes iso-8859-1 Blob per config', {
      my Blob $src = "%p café\n".encode('iso-8859-1');
      my $cfg = Template::HAML::Config.new(:encoding<iso-8859-1>);
      expect(HAML.render(:src($src), :config($cfg))).to.eq("<p>café</p>\n");
    }

    it 'throws X::HAML::EncodingError on invalid utf-8 bytes', {
      my Blob $src = Buf.new(0xFF, 0xFE, 0xFD);
      my $e = catch-it({ HAML.render(:$src) });
      expect($e).to.be-a(X::HAML::EncodingError);
      expect($e.encoding).to.be('utf-8');
    }
  }

  context 'source type validation', {
    it 'rejects numeric :src', {
      my $e = catch-it({ HAML.render(:src(42)) });
      expect($e).to.not.be-nil;
      expect($e.message).to.include('Str or Blob');
    }
  }

  context 'file slurp', {
    it 'honors configured encoding when reading from file', {
      my $tmp = $*TMPDIR.add('haml-encoding-' ~ $*PID ~ '.haml');
      $tmp.spurt("%p café\n".encode('iso-8859-1'));
      my $cfg  = Template::HAML::Config.new(:encoding<iso-8859-1>);
      my $haml = HAML.new(:config($cfg));
      expect($haml.render(:file($tmp.absolute))).to.eq("<p>café</p>\n");
      $tmp.unlink if $tmp.e;
    }

    it 'throws X::HAML::EncodingError on bad bytes from file path', {
      my $tmp = $*TMPDIR.add('haml-encoding-bad-' ~ $*PID ~ '.haml');
      $tmp.spurt(Buf.new(0xFF, 0xFE, 0xFD, 0x0A));
      my $haml = HAML.new;
      my $e = catch-it({ $haml.render(:file($tmp.absolute)) });
      expect($e).to.be-a(X::HAML::EncodingError);
      $tmp.unlink if $tmp.e;
    }
  }

  context 'render-cached', {
    it 'accepts Blob input', {
      my $tmp-cache = $*TMPDIR.add('haml-encoding-cache-' ~ (now.Rat * 1_000_000).Int);
      $tmp-cache.mkdir;
      my Blob $src = "%p café\n".encode('utf-8');
      my $haml = HAML.new(:compiled-cache-dir($tmp-cache));
      expect($haml.render-cached(:$src)).to.eq("<p>café</p>\n");
    }
  }

  context 'exception messages', {
    it 'X::HAML::InvalidEncoding names the encoding', {
      my $e = X::HAML::InvalidEncoding.new(:line(0), :column(0), :name<klingon>);
      expect($e.message).to.include('klingon');
    }

    it 'X::HAML::EncodingError mentions encoding and reason', {
      my $e = X::HAML::EncodingError.new(
        :line(0), :column(0), :encoding<utf-8>, :reason('bad bytes'),
      );
      expect($e.message).to.include('utf-8');
      expect($e.message).to.include('bad bytes');
    }
  }
}
