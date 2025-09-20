import { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, TextInput, Alert, Modal, Image } from 'react-native';
import { 
  Plus, Camera, Upload, Send, X, Clock, CheckCircle, 
  AlertTriangle, FileText, DollarSign, Hammer
} from 'lucide-react-native';
import * as ImagePicker from 'expo-image-picker';
import { createWorkProgress, getWorkProgress } from '../lib/supabase';
import { uploadMultipleImages } from '../lib/cloudinary';

export default function ContractorWorkProgress({ assignmentId, issueId, visible, onClose }) {
  const [progressData, setProgressData] = useState({
    title: '',
    description: '',
    progressPercentage: 0,
    laborHours: '',
    costsIncurred: '',
    nextSteps: '',
    issuesEncountered: '',
    estimatedCompletion: ''
  });
  const [selectedImages, setSelectedImages] = useState([]);
  const [progressHistory, setProgressHistory] = useState([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (visible) {
      loadProgressHistory();
    }
  }, [visible, assignmentId, issueId]);

  const loadProgressHistory = async () => {
    try {
      setLoading(true);
      const { data, error } = await getWorkProgress(assignmentId, issueId);
      if (error) throw error;
      setProgressHistory(data || []);
    } catch (error) {
      console.error('Error loading progress history:', error);
    } finally {
      setLoading(false);
    }
  };

  const pickImages = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      allowsMultipleSelection: true,
      aspect: [4, 3],
      quality: 0.8,
    });

    if (!result.canceled) {
      setSelectedImages([...selectedImages, ...result.assets]);
    }
  };

  const takePhoto = async () => {
    const result = await ImagePicker.launchCameraAsync({
      aspect: [4, 3],
      quality: 0.8,
    });

    if (!result.canceled) {
      setSelectedImages([...selectedImages, ...result.assets]);
    }
  };

  const removeImage = (index) => {
    setSelectedImages(selectedImages.filter((_, i) => i !== index));
  };

  const submitProgress = async () => {
    if (!progressData.title || !progressData.description) {
      Alert.alert('Error', 'Please fill in title and description');
      return;
    }

    try {
      setSubmitting(true);

      // Upload images if any
      let imageUrls = [];
      if (selectedImages.length > 0) {
        const imageUris = selectedImages.map(img => img.uri);
        const uploadResult = await uploadMultipleImages(imageUris);
        
        if (uploadResult.successful.length > 0) {
          imageUrls = uploadResult.successful.map(result => result.url);
        }
      }

      const progressPayload = {
        assignment_id: assignmentId,
        issue_id: issueId,
        progress_type: 'update',
        title: progressData.title,
        description: progressData.description,
        progress_percentage: parseInt(progressData.progressPercentage) || 0,
        images: imageUrls,
        labor_hours: parseFloat(progressData.laborHours) || 0,
        costs_incurred: parseFloat(progressData.costsIncurred) || 0,
        next_steps: progressData.nextSteps,
        issues_encountered: progressData.issuesEncountered,
        estimated_completion: progressData.estimatedCompletion || null,
        is_milestone: parseInt(progressData.progressPercentage) >= 100,
        requires_approval: parseInt(progressData.progressPercentage) >= 100
      };

      const { error } = await createWorkProgress(progressPayload);
      if (error) throw error;

      Alert.alert(
        'Success',
        'Work progress has been submitted successfully',
        [
          {
            text: 'OK',
            onPress: () => {
              setProgressData({
                title: '',
                description: '',
                progressPercentage: 0,
                laborHours: '',
                costsIncurred: '',
                nextSteps: '',
                issuesEncountered: '',
                estimatedCompletion: ''
              });
              setSelectedImages([]);
              loadProgressHistory();
              onClose();
            }
          }
        ]
      );
    } catch (error) {
      console.error('Error submitting progress:', error);
      Alert.alert('Error', 'Failed to submit progress: ' + error.message);
    } finally {
      setSubmitting(false);
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getProgressTypeIcon = (type) => {
    switch (type) {
      case 'milestone': return <CheckCircle size={16} color="#10B981" />;
      case 'issue': return <AlertTriangle size={16} color="#EF4444" />;
      case 'completion': return <CheckCircle size={16} color="#10B981" />;
      default: return <Clock size={16} color="#1E40AF" />;
    }
  };

  return (
    <Modal visible={visible} transparent animationType="slide">
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          <View style={styles.modalHeader}>
            <Text style={styles.modalTitle}>Work Progress Update</Text>
            <TouchableOpacity onPress={onClose}>
              <X size={24} color="#6B7280" />
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalForm}>
            {/* Progress Form */}
            <View style={styles.formSection}>
              <Text style={styles.sectionTitle}>Progress Update</Text>
              
              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Update Title *</Text>
                <TextInput
                  style={styles.textInput}
                  value={progressData.title}
                  onChangeText={(text) => setProgressData({...progressData, title: text})}
                  placeholder="Brief title for this update"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Progress Description *</Text>
                <TextInput
                  style={[styles.textInput, styles.textArea]}
                  value={progressData.description}
                  onChangeText={(text) => setProgressData({...progressData, description: text})}
                  placeholder="Detailed description of work completed"
                  multiline
                  numberOfLines={4}
                />
              </View>

              <View style={styles.inputRow}>
                <View style={styles.inputGroupHalf}>
                  <Text style={styles.inputLabel}>Progress (%)</Text>
                  <TextInput
                    style={styles.textInput}
                    value={String(progressData.progressPercentage)}
                    onChangeText={(text) => setProgressData({...progressData, progressPercentage: text})}
                    placeholder="0-100"
                    keyboardType="numeric"
                  />
                </View>
                <View style={styles.inputGroupHalf}>
                  <Text style={styles.inputLabel}>Labor Hours</Text>
                  <TextInput
                    style={styles.textInput}
                    value={progressData.laborHours}
                    onChangeText={(text) => setProgressData({...progressData, laborHours: text})}
                    placeholder="0.0"
                    keyboardType="numeric"
                  />
                </View>
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Costs Incurred ($)</Text>
                <TextInput
                  style={styles.textInput}
                  value={progressData.costsIncurred}
                  onChangeText={(text) => setProgressData({...progressData, costsIncurred: text})}
                  placeholder="0.00"
                  keyboardType="numeric"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Next Steps</Text>
                <TextInput
                  style={[styles.textInput, styles.textArea]}
                  value={progressData.nextSteps}
                  onChangeText={(text) => setProgressData({...progressData, nextSteps: text})}
                  placeholder="What will be done next?"
                  multiline
                  numberOfLines={3}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Issues Encountered</Text>
                <TextInput
                  style={[styles.textInput, styles.textArea]}
                  value={progressData.issuesEncountered}
                  onChangeText={(text) => setProgressData({...progressData, issuesEncountered: text})}
                  placeholder="Any problems or delays?"
                  multiline
                  numberOfLines={3}
                />
              </View>

              {/* Photo Upload */}
              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>Progress Photos</Text>
                <View style={styles.mediaContainer}>
                  <TouchableOpacity style={styles.mediaButton} onPress={takePhoto}>
                    <Camera size={20} color="#1E40AF" />
                    <Text style={styles.mediaButtonText}>Take Photo</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.mediaButton} onPress={pickImages}>
                    <Upload size={20} color="#1E40AF" />
                    <Text style={styles.mediaButtonText}>Upload Photos</Text>
                  </TouchableOpacity>
                </View>

                {selectedImages.length > 0 && (
                  <ScrollView horizontal style={styles.imagePreview} showsHorizontalScrollIndicator={false}>
                    {selectedImages.map((image, index) => (
                      <View key={index} style={styles.imageContainer}>
                        <Image source={{ uri: image.uri }} style={styles.previewImage} />
                        <TouchableOpacity
                          style={styles.removeImageButton}
                          onPress={() => removeImage(index)}
                        >
                          <X size={16} color="#FFFFFF" />
                        </TouchableOpacity>
                      </View>
                    ))}
                  </ScrollView>
                )}
              </View>
            </View>

            {/* Progress History */}
            <View style={styles.historySection}>
              <Text style={styles.sectionTitle}>Progress History</Text>
              {progressHistory.length === 0 ? (
                <Text style={styles.noHistoryText}>No progress updates yet</Text>
              ) : (
                <View style={styles.historyList}>
                  {progressHistory.slice(0, 5).map((progress) => (
                    <View key={progress.id} style={styles.historyItem}>
                      <View style={styles.historyHeader}>
                        <View style={styles.historyMeta}>
                          {getProgressTypeIcon(progress.progress_type)}
                          <Text style={styles.historyTitle}>{progress.title}</Text>
                        </View>
                        <Text style={styles.historyDate}>{formatDate(progress.created_at)}</Text>
                      </View>
                      <Text style={styles.historyDescription} numberOfLines={2}>
                        {progress.description}
                      </Text>
                      {progress.progress_percentage !== null && (
                        <Text style={styles.historyProgress}>
                          Progress: {progress.progress_percentage}%
                        </Text>
                      )}
                    </View>
                  ))}
                </View>
              )}
            </View>
          </ScrollView>

          {/* Submit Button */}
          <View style={styles.modalActions}>
            <TouchableOpacity
              style={styles.modalCancelButton}
              onPress={onClose}
            >
              <Text style={styles.modalCancelText}>Cancel</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.modalSubmitButton, submitting && styles.modalSubmitButtonDisabled]}
              onPress={submitProgress}
              disabled={submitting}
            >
              <Send size={16} color="#FFFFFF" />
              <Text style={styles.modalSubmitText}>
                {submitting ? 'Submitting...' : 'Submit Update'}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
    width: '100%',
    maxHeight: '90%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB',
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#111827',
  },
  modalForm: {
    flex: 1,
    padding: 20,
  },
  formSection: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#111827',
    marginBottom: 16,
  },
  inputGroup: {
    marginBottom: 16,
  },
  inputRow: {
    flexDirection: 'row',
    gap: 12,
  },
  inputGroupHalf: {
    flex: 1,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#111827',
    marginBottom: 6,
  },
  textInput: {
    backgroundColor: '#F9FAFB',
    borderWidth: 1,
    borderColor: '#E5E7EB',
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 14,
    color: '#111827',
  },
  textArea: {
    height: 80,
    textAlignVertical: 'top',
  },
  mediaContainer: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 16,
  },
  mediaButton: {
    flex: 1,
    backgroundColor: '#F0F9FF',
    borderWidth: 2,
    borderColor: '#1E40AF',
    borderStyle: 'dashed',
    borderRadius: 12,
    paddingVertical: 16,
    alignItems: 'center',
    gap: 6,
  },
  mediaButtonText: {
    fontSize: 12,
    fontWeight: '500',
    color: '#1E40AF',
  },
  imagePreview: {
    marginTop: 12,
  },
  imageContainer: {
    position: 'relative',
    marginRight: 12,
  },
  previewImage: {
    width: 80,
    height: 80,
    borderRadius: 8,
  },
  removeImageButton: {
    position: 'absolute',
    top: -8,
    right: -8,
    backgroundColor: '#EF4444',
    borderRadius: 12,
    width: 24,
    height: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  historySection: {
    borderTopWidth: 1,
    borderTopColor: '#E5E7EB',
    paddingTop: 20,
  },
  noHistoryText: {
    fontSize: 14,
    color: '#6B7280',
    textAlign: 'center',
    fontStyle: 'italic',
  },
  historyList: {
    gap: 12,
  },
  historyItem: {
    backgroundColor: '#F9FAFB',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E5E7EB',
  },
  historyHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 6,
  },
  historyMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flex: 1,
  },
  historyTitle: {
    fontSize: 14,
    fontWeight: '600',
    color: '#111827',
  },
  historyDate: {
    fontSize: 12,
    color: '#9CA3AF',
  },
  historyDescription: {
    fontSize: 12,
    color: '#6B7280',
    marginBottom: 4,
  },
  historyProgress: {
    fontSize: 12,
    color: '#1E40AF',
    fontWeight: '600',
  },
  modalActions: {
    flexDirection: 'row',
    gap: 12,
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#E5E7EB',
  },
  modalCancelButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#E5E7EB',
    alignItems: 'center',
  },
  modalCancelText: {
    color: '#374151',
    fontSize: 14,
    fontWeight: '600',
  },
  modalSubmitButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#1E40AF',
    gap: 6,
  },
  modalSubmitButtonDisabled: {
    opacity: 0.6,
  },
  modalSubmitText: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
});