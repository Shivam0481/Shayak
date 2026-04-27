const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Haversine formula to calculate distance between two lat/lng points in km
function getDistanceFromLatLonInKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
}

exports.notifyNearbyVolunteers = functions.firestore
  .document('requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    
    const reqLocation = requestData.location; // GeoPoint
    if (!reqLocation) {
      console.log('No location found in request.');
      return null;
    }

    const radiusKm = requestData.searchRadiusKm || 10;
    const reqLat = reqLocation.latitude;
    const reqLng = reqLocation.longitude;

    try {
      // Fetch available volunteers
      const usersSnapshot = await admin.firestore().collection('users')
        .where('isAvailable', '==', true)
        .get();

      const tokens = [];

      usersSnapshot.forEach(userDoc => {
        if (userDoc.id === requestData.creatorId) return; // Don't notify creator

        const userData = userDoc.data();
        if (userData.latitude && userData.longitude && userData.fcmToken) {
          const dist = getDistanceFromLatLonInKm(reqLat, reqLng, userData.latitude, userData.longitude);
          
          if (dist <= radiusKm) {
            tokens.push(userData.fcmToken);
          }
        }
      });

      if (tokens.length === 0) {
        console.log('No available volunteers nearby.');
        return null;
      }

      console.log(`Sending notification to ${tokens.length} volunteers.`);

      const message = {
        notification: {
          title: `New ${requestData.type} Request Nearby`,
          body: requestData.description || 'A new disaster rescue request was created near you.',
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`${response.successCount} messages were sent successfully.`);
      return null;
    } catch (error) {
      console.error('Error sending notifications:', error);
      return null;
    }
  });
