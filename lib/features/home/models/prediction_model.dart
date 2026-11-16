class PredictionModel {
  String? description;
  String? placeId;
  List<MatchedSubstring>? matchedSubstrings;
  String? reference;
  StructuredFormatting? structuredFormatting;
  List<Term>? terms;
  List<String>? types;

  PredictionModel({
    this.description,
    this.placeId,
    this.matchedSubstrings,
    this.reference,
    this.structuredFormatting,
    this.terms,
    this.types,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      description: json['description'],
      placeId: json['place_id'],
      matchedSubstrings: json['matched_substrings'] != null
          ? List<MatchedSubstring>.from(
              json['matched_substrings'].map((x) => MatchedSubstring.fromJson(x)))
          : null,
      reference: json['reference'],
      structuredFormatting: json['structured_formatting'] != null
          ? StructuredFormatting.fromJson(json['structured_formatting'])
          : null,
      terms: json['terms'] != null
          ? List<Term>.from(json['terms'].map((x) => Term.fromJson(x)))
          : null,
      types: json['types'] != null ? List<String>.from(json['types']) : null,
    );
  }
}

class MatchedSubstring {
  int? length;
  int? offset;

  MatchedSubstring({this.length, this.offset});

  factory MatchedSubstring.fromJson(Map<String, dynamic> json) {
    return MatchedSubstring(
      length: json['length'],
      offset: json['offset'],
    );
  }
}

class StructuredFormatting {
  String? mainText;
  List<MatchedSubstring>? mainTextMatchedSubstrings;
  String? secondaryText;
  List<MatchedSubstring>? secondaryTextMatchedSubstrings;

  StructuredFormatting({
    this.mainText,
    this.mainTextMatchedSubstrings,
    this.secondaryText,
    this.secondaryTextMatchedSubstrings,
  });

  factory StructuredFormatting.fromJson(Map<String, dynamic> json) {
    return StructuredFormatting(
      mainText: json['main_text'],
      mainTextMatchedSubstrings: json['main_text_matched_substrings'] != null
          ? List<MatchedSubstring>.from(json['main_text_matched_substrings']
                  .map((x) => MatchedSubstring.fromJson(x)))
          : null,
      secondaryText: json['secondary_text'],
      secondaryTextMatchedSubstrings:
          json['secondary_text_matched_substrings'] != null
              ? List<MatchedSubstring>.from(
                  json['secondary_text_matched_substrings']
                      .map((x) => MatchedSubstring.fromJson(x)))
              : null,
    );
  }
}

class Term {
  int? offset;
  String? value;

  Term({this.offset, this.value});

  factory Term.fromJson(Map<String, dynamic> json) {
    return Term(
      offset: json['offset'],
      value: json['value'],
    );
  }
}
