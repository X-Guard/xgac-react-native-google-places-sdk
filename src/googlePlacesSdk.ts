import { NativeModules, Platform } from 'react-native';
import type {
  FieldsParam,
  Place,
  PlacePrediction,
  PredictionFiltersParam,
  SearchNearbyFiltersParam,
  SearchPrediction,
  SearchTextFiltersParam,
} from './types';

const LINKING_ERROR =
  `The package 'react-native-google-places-sdk' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const GooglePlacesSdk = NativeModules.GooglePlacesSdk
  ? NativeModules.GooglePlacesSdk
  : new Proxy(
    {},
    {
      get() {
        throw new Error(LINKING_ERROR);
      },
    }
  );

export function initialize(apiKey: string) {
  if (!apiKey) return;
  GooglePlacesSdk.initialize(apiKey);
}

export async function fetchPredictions(
  query: string,
  filters: PredictionFiltersParam = {}
): Promise<PlacePrediction[]> {
  const predictions = await GooglePlacesSdk.fetchPredictions(query, filters);

  return predictions;
}

export async function fetchPlaceByID(
  placeID: string,
  fields: FieldsParam = []
): Promise<Place> {
  const place = await GooglePlacesSdk.fetchPlaceByID(placeID, fields);

  return place;
}

export async function searchByText(
  query: string,
  filters: SearchTextFiltersParam = {}
): Promise<SearchPrediction[]> {
  const predictions = await GooglePlacesSdk.searchByText(query, filters);

  return predictions;
}

export async function searchNearby(
  options: {
    latitude: number,
    longitude: number,
    radius: number,
  },
  filters: SearchNearbyFiltersParam = {}
): Promise<SearchPrediction[]> {
  const places = await GooglePlacesSdk.searchNearby(options, filters);

  return places;
}

export async function startNewSession() {
  const msg = await GooglePlacesSdk.startNewSession();

  return msg;
}

export async function clearSession() {
  const msg = await GooglePlacesSdk.clearSession();

  return msg;
}
