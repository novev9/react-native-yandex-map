import { StyleSheet, View } from 'react-native';
import { YandexMapView } from 'react-native-yandex-map';

export default function App() {
  return (
    <View style={styles.container}>
      <YandexMapView
        style={styles.map}
        initialRegion={{ lat: 55.751244, lon: 37.618423, zoom: 12 }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  map: { flex: 1 },
});
