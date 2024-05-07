import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:testupload/app/constants/string.dart';
import '../../../data/repo/repo.dart';
import '../../../model/image_response_model.dart';
import '../../../reusable/index.dart';

class HomeController extends GetxController {
  //==============================================================================
  // * Properties *
  //==============================================================================
  var isLoading = false.obs;
  Rx<ImageResponseModel> imgDataResponse = ImageResponseModel().obs;
  Rx<ImageResponseModel> filteredImgData = ImageResponseModel().obs;
  final Debounce debounce = Debounce(const Duration(milliseconds: 700));
  RxList<Hit> hitList = <Hit>[].obs;
  RxList<Hit> filterHitList = <Hit>[].obs;
  var searchController = TextEditingController();
  var isMoreDataLoading = false.obs;
  ScrollController scrollController = ScrollController();
  var page = 1.obs;

  //==============================================================================
  // * GetX Life cycle *
  //==============================================================================

  @override
  void onInit() {
    initFunction();
    scrollController.addListener(scrollListener);

    initializeFirebaseMessaging();
    getLocalDb();

    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    debounce.dispose();
    super.onClose();
  }

  //==============================================================================
  // * Helper *
  //==============================================================================

  // function for initial loading
  Future<void> initFunction() async {
    isLoading(true);
    getImageData(1).then((value) => filterImages(emptyString));

    isLoading(false);
  }

  ///  method with detect scrolling

  Future<void> scrollListener() async {
    if (scrollController.position.pixels ==
        scrollController.position.maxScrollExtent) {
      if (page.value <=
          ((50 / (imgDataResponse.value.totalHits ?? 500)) * 100)) {
        if (isMoreDataLoading.isFalse) {
          isMoreDataLoading(true);
          await getImageData(page.value);
        }
      }
    }
  }

  /// for inititalize the firebase messeging
  void initializeFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');
      // Listen for incoming messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
        }
      });
    } catch (e) {
      print('Error initializing Firebase Messaging: $e');
      // Handle error appropriately
    }
  }

  //method for fetch data from the api

  Future<void> getImageData(int pag) async {
    try {
      final response = await Repo.getInstance().getImageData(page);
      if (response.hits != null && (response.hits?.isNotEmpty ?? false)) {
        page++;
      }
      imgDataResponse.value = response;
      hitList.addAll(response.hits ?? []);

      await storeLocalData(response);

      // });
    } catch (e) {
    } finally {
      isMoreDataLoading(false);
    }
  }

// method for the filter data
  void filterImages(String? query) {
    if (query == null || query.isEmpty) {
      filterHitList = hitList;
      filteredImgData.value = imgDataResponse.value;
    } else {
      filterHitList.value = hitList.where((image) {
            return (image.tags != null &&
                image.tags!.toLowerCase().contains(query.toLowerCase()));
          }).toList() ??
          [];
    }
  }

  /// method for the store the data into hive database
  Future<void> storeLocalData(ImageResponseModel imageData) async {
    try {
      final box = await Hive.openBox<Map>('imageData');
      if (box != null) {
        await box.clear(); // Clear existing data
        await box.put('data', imageData.toJson()); // Store new data
        print('Image data stored successfully: $imageData');
      } else {
        throw 'Error: Failed to open Hive box.';
      }
    } catch (e) {
      throw 'Error storing image data: $e';
    }
  }

// get the data stored data into Hive
  Future<void> getLocalDb() async {
    try {
      final box = await Hive.openBox<Map>('imageData');
      if (box != null) {
        final jsonData = box.get('data');
        if (jsonData != null) {
          final imageData =
              ImageResponseModel.fromJson(jsonData.cast<String, dynamic>());
          print('Retrieved Image Data: $imageData');
          imgDataResponse.value = imageData;
        } else {
          throw 'No data found in Hive box.';
        }
      } else {
        throw 'Error: Failed to open Hive box.';
      }
    } catch (e) {
      throw 'Error retrieving image data: $e';
    }
  }

  // method for the perform toggle like function

  Future<void> toggleLike(int imageId) async {
    try {
      final box = await Hive.openBox<Map>('imageData');
      final imageDataMap = box.get('data');

      if (imageDataMap != null) {
        if (imageDataMap.containsKey(imageId.toString())) {
          final Map<String, dynamic> updatedImage =
              imageDataMap[imageId.toString()];

          // Toggle the 'isLiked' status
          final bool currentLikeStatus = updatedImage['isLiked'] ?? false;
          updatedImage['isLiked'] = !currentLikeStatus;

          // Update the image in the map
          imageDataMap[imageId.toString()] = updatedImage;

          // Save the updated map back to Hive
          await box.put('data', imageDataMap);

          print(
              'Toggle like for imageId: $imageId, isLiked: ${updatedImage['isLiked']}');
        } else {
          throw 'Image with ID $imageId not found in Hive box.';
        }
      } else {
        throw 'No data found in Hive box.';
      }
    } catch (e) {
      throw 'Error toggling like: $e';
    }
  }
}
