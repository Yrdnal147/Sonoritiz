import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart' as import_go_router;

class ArtistNameDisplay extends StatelessWidget {
  final String artistName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const ArtistNameDisplay({
    Key? key,
    required this.artistName,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
  }) : super(key: key);

  String _normalizeArtistString(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(
            r'[\(\[]\s*(feat\.?|ft\.?|featuring|with|avec)\s+([^\)\]]+)[\)\]]',
            caseSensitive: false,
          ),
          (m) => ' feat. ${m.group(2)?.trim() ?? ''}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _openArtist(BuildContext context, String name) {
    final clean = name.replaceAll(RegExp(r'^[\(\[]+|[\)\]]+$'), '').trim();
    if (clean.isEmpty) return;
    final router = import_go_router.GoRouter.of(context);
    Navigator.of(context, rootNavigator: true).popUntil((route) => route is! PopupRoute);
    router.push('/artist', extra: {'name': clean});
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedName = _normalizeArtistString(artistName);
    final TextStyle defaultStyle = style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );

    // Séparateurs de featuring : " feat. ", " ft. ", " featuring ", " & ", " and ", ", "
    final RegExp separatorRegExp = RegExp(
      r'(\s+(?:feat\.?|ft\.?|featuring|and|&|x)\s+|,\s+)',
      caseSensitive: false,
    );

    if (!separatorRegExp.hasMatch(normalizedName)) {
      return GestureDetector(
        onTap: () => _openArtist(context, normalizedName),
        child: Text(
          normalizedName,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
          style: defaultStyle,
        ),
      );
    }

    final Iterable<RegExpMatch> matches =
        separatorRegExp.allMatches(normalizedName);
    int lastMatchEnd = 0;
    final List<InlineSpan> spans = [];

    final TextStyle separatorStyle = defaultStyle.copyWith(
      color: (defaultStyle.color ?? Colors.white).withOpacity(0.65),
      fontWeight: FontWeight.w400,
    );

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        final String artistPart =
            normalizedName.substring(lastMatchEnd, match.start);
        spans.add(
          TextSpan(
            text: artistPart,
            style: defaultStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openArtist(context, artistPart),
          ),
        );
      }

      final String sepText = match.group(0) ?? ' feat. ';
      spans.add(
        TextSpan(
          text: sepText,
          style: separatorStyle,
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < normalizedName.length) {
      final String lastArtistPart = normalizedName.substring(lastMatchEnd);
      spans.add(
        TextSpan(
          text: lastArtistPart,
          style: defaultStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openArtist(context, lastArtistPart),
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
