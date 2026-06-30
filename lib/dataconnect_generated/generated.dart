library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_user.dart';

part 'get_projects.dart';

part 'create_task.dart';

part 'delete_task.dart';







class ExampleConnector {
  
  
  CreateUserVariablesBuilder createUser ({required String email, required String displayName, }) {
    return CreateUserVariablesBuilder(dataConnect, email: email,displayName: displayName,);
  }
  
  
  GetProjectsVariablesBuilder getProjects () {
    return GetProjectsVariablesBuilder(dataConnect, );
  }
  
  
  CreateTaskVariablesBuilder createTask ({required String title, required String status, required String projectId, }) {
    return CreateTaskVariablesBuilder(dataConnect, title: title,status: status,projectId: projectId,);
  }
  
  
  DeleteTaskVariablesBuilder deleteTask ({required String id, }) {
    return DeleteTaskVariablesBuilder(dataConnect, id: id,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'easyrealtorspro',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    
    CacheSettings cacheSettings = CacheSettings(
      maxAge: Duration(milliseconds:0),
      storage: CacheStorage.persistent,
    );
    
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            
            cacheSettings: cacheSettings,
            
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}
