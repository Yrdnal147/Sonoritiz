import 'package:flutter/material.dart';

class ArtistNameDisplay extends StatelessWidget {
  final String artistName;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const ArtistNameDisplay({
    Key? key,
    required this.artistName,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextStyle defaultStyle = style ?? const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500);
    
    // Regular expression to match standard featuring words/symbols with spaces
    // e.g. " and ", " & ", " feat ", " ft. ", etc.
    final RegExp featRegExp = RegExp(r'\s+(and|&|feat\.?|ft\.?)\s+', caseSensitive: false);
    
    if (!featRegExp.hasMatch(artistName)) {
      return Text(
        artistName,
        maxLines: maxLines,
        overflow: overflow,
        style: defaultStyle,
      );
    }

    final Iterable<RegExpMatch> matches = featRegExp.allMatches(artistName);
    int lastMatchEnd = 0;
    List<InlineSpan> spans = [];

    final double logoHeight = (defaultStyle.fontSize ?? 14.0) * 0.8;

    for (var match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: artistName.substring(lastMatchEnd, match.start)));
      }
      
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Image.asset(
            'assets/images/logo_transparent.png',
            height: logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Text(
              match.group(0) ?? ' & ',
              style: defaultStyle,
            ),
          ),
        ),
      ));
      
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < artistName.length) {
      spans.add(TextSpan(text: artistName.substring(lastMatchEnd)));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
    );
  }
}
