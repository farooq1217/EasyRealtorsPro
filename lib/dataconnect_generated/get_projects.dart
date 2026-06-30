part of 'generated.dart';

class GetProjectsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  GetProjectsVariablesBuilder(this._dataConnect, );
  Deserializer<GetProjectsData> dataDeserializer = (dynamic json)  => GetProjectsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<GetProjectsData, void>> execute({QueryFetchPolicy fetchPolicy = QueryFetchPolicy.preferCache}) {
    return ref().execute(fetchPolicy: fetchPolicy);
  }

  QueryRef<GetProjectsData, void> ref() {
    
    return _dataConnect.query("GetProjects", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class GetProjectsProjects {
  final String title;
  final String? description;
  final GetProjectsProjectsOwner owner;
  GetProjectsProjects.fromJson(dynamic json):
  
  title = nativeFromJson<String>(json['title']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']),
  owner = GetProjectsProjectsOwner.fromJson(json['owner']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProjectsProjects otherTyped = other as GetProjectsProjects;
    return title == otherTyped.title && 
    description == otherTyped.description && 
    owner == otherTyped.owner;
    
  }
  @override
  int get hashCode => Object.hashAll([title.hashCode, description.hashCode, owner.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['title'] = nativeToJson<String>(title);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    json['owner'] = owner.toJson();
    return json;
  }

  GetProjectsProjects({
    required this.title,
    this.description,
    required this.owner,
  });
}

@immutable
class GetProjectsProjectsOwner {
  final String displayName;
  GetProjectsProjectsOwner.fromJson(dynamic json):
  
  displayName = nativeFromJson<String>(json['displayName']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProjectsProjectsOwner otherTyped = other as GetProjectsProjectsOwner;
    return displayName == otherTyped.displayName;
    
  }
  @override
  int get hashCode => displayName.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['displayName'] = nativeToJson<String>(displayName);
    return json;
  }

  GetProjectsProjectsOwner({
    required this.displayName,
  });
}

@immutable
class GetProjectsData {
  final List<GetProjectsProjects> projects;
  GetProjectsData.fromJson(dynamic json):
  
  projects = (json['projects'] as List<dynamic>)
        .map((e) => GetProjectsProjects.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final GetProjectsData otherTyped = other as GetProjectsData;
    return projects == otherTyped.projects;
    
  }
  @override
  int get hashCode => projects.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['projects'] = projects.map((e) => e.toJson()).toList();
    return json;
  }

  GetProjectsData({
    required this.projects,
  });
}

