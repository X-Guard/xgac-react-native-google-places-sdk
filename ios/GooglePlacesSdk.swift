//
//  GooglePlacesSdkUtils.swift
//  GooglePlacesSdk
//
//  Created by Farid Ansari on 25/01/23.
//  Copyright © 2023 Facebook. All rights reserved.
//

import Foundation
import GooglePlaces

let NOT_INITIALIZED_MSG = "Google Places not initialized. Initialize by calling initialize method before calling any other methods"
let NEW_SESSION_CREATED = "NEW_SESSION_CREATED"
let SESSION_CLEARED = "SESSION_CLEARED";
let NO_ACTIVE_SESSION = "NO_ACTIVE_SESSION";

@objc(GooglePlacesSdk)
class GooglePlacesSdk: NSObject {
  private var client: GMSPlacesClient? = nil;
  private var sessionToken: GMSAutocompleteSessionToken? = nil;

  @objc
  func initialize(_ apiKey: String) -> Void {
    DispatchQueue.main.async {
      GMSPlacesClient.provideAPIKey(apiKey)
      self.client = GMSPlacesClient.shared()
    }
  }

  @objc
  func startNewSession(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
      guard let client = self.client else {
          reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
          return
      }

      self.sessionToken = GMSAutocompleteSessionToken()
      resolve(NEW_SESSION_CREATED)
  }

  @objc
  func clearSession(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
      guard let _ = self.client else {
          reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
          return
      }

      if self.sessionToken == nil {
          resolve(NO_ACTIVE_SESSION)
          return
      }

      self.sessionToken = nil
      resolve(SESSION_CLEARED)
  }

  @objc
  func fetchPredictions(_ query: String, filterOptions: NSDictionary,  resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let client = self.client else {
      reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
      return
    }

    // Use sessionToken if it exists, otherwise create a new one
    self.sessionToken = self.sessionToken ?? GMSAutocompleteSessionToken()

    let filter = AutocompleteFilterFromOptions(filterOptions)
    client.findAutocompletePredictions(
      fromQuery: query,
      filter: filter,
      sessionToken: self.sessionToken,
      callback: {(results, error) in
        guard let results = results, error == nil else {
          let errorCode = error?._code ?? 0
          let errorMsg = error?.localizedDescription ?? "Unknown Error"
          reject(String(errorCode), errorMsg, error)
          return
        }


        let predictions: NSMutableArray = []
        for result in results {
          let dict: NSMutableDictionary = [
            "placeID": result.placeID,
            "description": result.attributedFullText.string,
            "primaryText": result.attributedPrimaryText.string,
            "secondaryText": result.attributedSecondaryText?.string ?? NSNull(),
            "types": result.types,
            "distanceMeters": result.distanceMeters?.intValue ?? NSNull()
          ]
          predictions.add(dict)
        }
        resolve(predictions)
      }
    )
  }

  @objc
  func searchByText(
    _ query: String,
    filterOptions: NSDictionary,
    resolver resolve: @escaping RCTPromiseResolveBlock,
    rejecter reject: @escaping RCTPromiseRejectBlock
  ) {
    guard let client = self.client else {
      reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
      return
    }

    // Create or reuse session token
    self.sessionToken = self.sessionToken ?? GMSAutocompleteSessionToken()

    // Define all place properties to request
    let properties: [String] = [
      GMSPlaceProperty.addressComponents,
      GMSPlaceProperty.name,
      GMSPlaceProperty.coordinate,
      GMSPlaceProperty.types,
      GMSPlaceProperty.placeID,
      GMSPlaceProperty.formattedAddress,
      GMSPlaceProperty.website
    ].map { $0.rawValue }

    let request = GMSPlaceSearchByTextRequest(textQuery: query, placeProperties: properties);

    // Add all filterOptions to the request if possible
    for (key, value) in filterOptions {
      guard let keyString = key as? String else { continue }
      switch keyString {
      case "includedType":
        if let type = value as? String {
          request.includeType = type
        }
      case "isStrictTypeFiltering":
        if let isStrict = value as? Bool {
          request.isStrictTypeFiltering = isStrict
        }
      case "maxResultCount":
        if let maxCount = value as? Int {
          request.maxResultCount = maxCount
        }
      case "minRating":
        if let minRating = value as? Double {
          request.minRating = minRating
        }
      case "rankPreference":
        if let rankPreference = value as? GMSPlaceSearchRankPreference {
          request.rankPreference = rankPreference
        } 
      case "regionCode":
        if let regionCode = value as? String {
          request.regionCode = regionCode
        }
      case "isOpenNow":
        if let isOpenNow = value as? Bool {
          request.isOpenNow = isOpenNow
        }
      case "locationBias":
        if let bias = value as? GMSPlaceLocationBiasOption {
          request.locationBias = bias
        }
      case "locationRestriction":
        if let restriction = value as? GMSPlaceLocationRestrictionOption {
          request.locationRestriction = restriction
        }
      case "shouldIncludePureServiceAreaBusinesses":
        if let shouldInclude = value as? Bool {
          request.shouldIncludePureServiceAreaBusinesses = shouldInclude
        }
      case "priceLevels":
        if let priceLevels = value as? [GMSPlacePriceLevel] {
          request.priceLevels = priceLevels
        }
      default:
        continue
      }
    }

    // Perform the search
    client.searchByText(with: request) { results, error in
      if let error = error {
        reject(String(error._code), error.localizedDescription, error)
        return
      }

      guard let places = results else {
        reject("0", "No results found", nil)
        return
      }

      let mappedResults: [[String: Any]] = places.map { place in
        var dict: [String: Any] = [:]
        dict["placeID"] = place.placeID ?? ""
        dict["name"] = place.name ?? ""
        dict["formattedAddress"] = place.formattedAddress ?? ""
        dict["types"] = place.types ?? []
        dict["url"] = place.website ?? []
        if let coordinate = place.coordinate as CLLocationCoordinate2D? {
          dict["coordinate"] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
        }

        return dict
      }

      resolve(mappedResults)
    }
  }


  @objc
  func searchNearby(
    _ options: NSDictionary,     
    filterOptions: NSDictionary, 
    resolver resolve: @escaping RCTPromiseResolveBlock, 
    rejecter reject: @escaping RCTPromiseRejectBlock
    ) {

    guard let latitude = options["latitude"] as? Double,
          let longitude = options["longitude"] as? Double,
          let radius = options["radius"] as? Double else {
      reject("INVALID_PARAMS", "Missing or invalid latitude/longitude/radius", nil)
      return
    }

    guard let client = self.client else {
      reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
      return
    }

    let circularLocationRestriction = GMSPlaceCircularLocationOption(CLLocationCoordinate2DMake(latitude , longitude ), radius )

    // Define all place properties to request
    let placeProperties: [String] = [
      GMSPlaceProperty.addressComponents,
      GMSPlaceProperty.name,
      GMSPlaceProperty.coordinate,
      GMSPlaceProperty.types,
      GMSPlaceProperty.placeID,
      GMSPlaceProperty.formattedAddress,
      GMSPlaceProperty.website
    ].map { $0.rawValue }

    var request = GMSPlaceSearchNearbyRequest(locationRestriction: circularLocationRestriction, placeProperties: placeProperties)

    for (key, value) in options {
      guard let keyString = key as? String else { continue }
      switch keyString {
      case "includedTypes":
        if let types = value as? [String] {
          request.includedTypes = types
        }
      case "excludedTypes":
        if let types = value as? [String] {
          request.excludedTypes = types
        }
      case "includedPrimaryTypes":
        if let types = value as? [String] {
          request.includedPrimaryTypes = types
        }
      case "excludedPrimaryTypes":
        if let types = value as? [String] {
          request.excludedPrimaryTypes = types
        }
      case "maxResultCount":
        if let maxCount = value as? Int {
          request.maxResultCount = maxCount
        }
      case "rankPreference":
        if let rankPreference = value as? GMSPlaceSearchRankPreference {
          request.rankPreference = rankPreference
        }
      case "regionCode":
        if let regionCode = value as? String {
          request.regionCode = regionCode
        }
      default:
        continue
      }
    }

    // Perform the search
    client.searchNearby(with: request) { results, error in
      if let error = error {
        reject(String(error._code), error.localizedDescription, error)
        return
      }

      guard let places = results else {
        reject("0", "No results found", nil)
        return
      }

      let mappedResults: [[String: Any]] = places.map { place in
        var dict: [String: Any] = [:]
        dict["placeID"] = place.placeID ?? ""
        dict["name"] = place.name ?? ""
        dict["formattedAddress"] = place.formattedAddress ?? ""
        dict["types"] = place.types ?? []
        dict["url"] = place.website ?? []
        if let coordinate = place.coordinate as CLLocationCoordinate2D? {
          dict["coordinate"] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]
        }

        return dict
      }

      resolve(mappedResults)
    }

  }

  @objc
  func fetchAutocompleteSuggestions(_ query: String, filterOptions: NSDictionary,  resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {

    guard let client = self.client else {
      reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
      return
    }

    // Use sessionToken if it exists, otherwise create a new one
    self.sessionToken = self.sessionToken ?? GMSAutocompleteSessionToken()

    let request = GMSAutocompleteRequest(query: query)
    request.filter = AutocompleteFilterFromOptions(filterOptions)
    request.sessionToken = self.sessionToken

    client.fetchAutocompleteSuggestions(from: request, callback: { ( results: Optional<Array<GMSAutocompleteSuggestion>>, error: Error? ) in
      guard let results = results, error == nil else {
        let errorCode = error?._code ?? 0
        let errorMsg = error?.localizedDescription ?? "Unknown Error"
        reject(String(errorCode), errorMsg, error)
        return
      }

      let parsedSuggestions = ParseSuggesttions(suggestions: results)
      resolve(parsedSuggestions)
    })
  }

  @objc
  func fetchPlaceByID(_ placeID: String, fields: NSArray, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let client = self.client else {
      reject("-1", NOT_INITIALIZED_MSG, NSError(domain: "", code: 0))
      return
    }

    let parsedFields = GMSPlaceFieldsFromFields(fields: fields)
    let fetchPlaceRequest = GMSFetchPlaceRequest(placeID: placeID, placeProperties: parsedFields, sessionToken: self.sessionToken)

    client.fetchPlace(with: fetchPlaceRequest, callback: {(place: GMSPlace?, error: Error?) in
      guard let place = place, error == nil else {
        let errorCode = error?._code ?? 0
        let errorMsg = error?.localizedDescription ?? "Unknown Error"
        reject(String(errorCode), errorMsg, error)
        return
      }

      let parsedPlace = ParsePlace(place: place)
      resolve(parsedPlace)

      self.sessionToken = nil
    })

  }
}
