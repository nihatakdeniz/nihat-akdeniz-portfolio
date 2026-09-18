# Sanitized acoustic scene training code
# Kaggle credentials are intentionally omitted. Set KAGGLE_API_TOKEN locally via a secret manager or environment variable.

import os


# Hedef klasörü oluşturuyoruz
# Colab shell command omitted from this public candidate.

print("Veri seti indiriliyor ve otomatik olarak dışarı çıkartılıyor...")
print("Aşağıda canlı ilerleme çubuğunu (yüzde oranını) görebilirsin:\n")

# '!' kullanımı sayesinde Colab indirme yüzdesini canlı gösterecektir.
# '--unzip' komutu indirme biter bitmez otomatik olarak zip'ten çıkarır.
# Dataset download command omitted; use the official Kaggle CLI locally after authenticating.
import glob
import pandas as pd
import torch
import torchaudio
from torch.utils.data import Dataset

class AcousticSceneDataset(Dataset):
    def __init__(self, audio_dir, sample_rate=16000, n_mels=64, n_fft=1024, hop_length=512):
        self.audio_dir = audio_dir
        self.sample_rate = sample_rate

        # Spektrogram dönüşüm ayarları
        self.mel_transform = torchaudio.transforms.MelSpectrogram(
            sample_rate=self.sample_rate, n_fft=n_fft, hop_length=hop_length, n_mels=n_mels
        )
        self.amplitude_to_db = torchaudio.transforms.AmplitudeToDB()

        # 1. Meta/Etiket dosyasını bulalım
        meta_files = glob.glob(os.path.join(audio_dir, "**/meta.csv"), recursive=True)
        if not meta_files:
            meta_files = glob.glob(os.path.join(audio_dir, "**/meta.tsv"), recursive=True)

        if not meta_files:
            raise FileNotFoundError("Hata: 'meta.csv' veya 'meta.tsv' dosyası audio_data klasöründe bulunamadı!")

        self.meta_path = meta_files[0]
        print(f"--> Başarıyla etiket dosyası bulundu: {self.meta_path}")

        self.meta_df = pd.read_csv(self.meta_path, sep=None, engine='python')
        self.meta_df.columns = [c.strip() for c in self.meta_df.columns]

        file_col = 'filename' if 'filename' in self.meta_df.columns else self.meta_df.columns[0]
        label_col = 'scene_label' if 'scene_label' in self.meta_df.columns else self.meta_df.columns[1]

        self.file_names = self.meta_df[file_col].tolist()
        self.labels = self.meta_df[label_col].tolist()

        unique_labels = sorted(list(set(self.labels)))
        self.labels_map = {label: i for i, label in enumerate(unique_labels)}

        # 2. KRİTİK DÜZELTME: Klasör karmaşasını çözmek için tüm diskteki .wav dosyalarını haritalıyoruz
        print("Disk üzerindeki gerçek ses konumları taranıyor ve eşleştiriliyor...")
        all_physical_wavs = glob.glob(os.path.join(audio_dir, "**/*.wav"), recursive=True)

        # Dosya adını (basenam_e) -> Tam dosya yoluna eşleyen sözlük yapısı
        self.audio_path_map = {os.path.basename(p): p for p in all_physical_wavs}
        print(f"--> Başarıyla {len(self.audio_path_map)} adet fiziksel ses dosyası hafızaya haritalandı!")

    def __len__(self):
        return len(self.file_names)

    def __getitem__(self, idx):
        # CSV'den gelen dosya adının sadece saf adını alıyoruz (Örn: street_pedestrian-...wav)
        pure_filename = os.path.basename(self.file_names[idx].replace('\\', '/'))

        # Dosyayı diskte taradığımız gerçek konumundan çekiyoruz
        if pure_filename in self.audio_path_map:
            file_path = self.audio_path_map[pure_filename]
        else:
            # Eğer taramada bulunamadıysa son çare olarak hata fırlatmadan önce varsayılan yolu dene
            file_path = os.path.join(os.path.dirname(self.meta_path), self.file_names[idx])

        waveform, sr = torchaudio.load(file_path)

        if sr != self.sample_rate:
            resampler = torchaudio.transforms.Resample(sr, self.sample_rate)
            waveform = resampler(waveform)

        if waveform.shape[0] > 1:
            waveform = torch.mean(waveform, dim=0, keepdim=True)

        mel_spec = self.mel_transform(waveform)
        mel_spec_db = self.amplitude_to_db(mel_spec)

        label_str = self.labels[idx]
        label = self.labels_map[label_str]

        return mel_spec_db.squeeze(0), label
import torch.nn as nn
import torchvision.models as models

class MobileNetFeatureExtractor(nn.Module):
    def __init__(self, embedding_dim=256):
        super(MobileNetFeatureExtractor, self).__init__()
        # Hız ve performans dengesi için MobileNet V3 Small tercih ediyoruz
        mobilenet = models.mobilenet_v3_small(pretrained=True)

        # Giriş kanalını spektrogram için 1 yapıyoruz (Varsayılan 3 kanaldır)
        old_conv = mobilenet.features[0][0]
        new_conv = nn.Conv2d(1, old_conv.out_channels,
                             kernel_size=old_conv.kernel_size,
                             stride=old_conv.stride,
                             padding=old_conv.padding, bias=False)

        with torch.no_grad():
            new_conv.weight[:] = old_conv.weight.sum(dim=1, keepdim=True)
        mobilenet.features[0][0] = new_conv

        # Öznitelik çıkarma katmanları ve Pooling
        self.features = mobilenet.features
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        self.fc = nn.Linear(576, embedding_dim) # V3 Small çıkışı 576 kanaldır

    def forward(self, x):
        # x shape: [Batch * Time_Steps, 1, Freq, Window_Width]
        x = self.features(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x) # Çıktı: [Batch * Time_Steps, embedding_dim]
        return x

class AudioTemporalTransformer(nn.Module):
    def __init__(self, embedding_dim=256, num_heads=4, num_layers=3, num_classes=10):
        super(AudioTemporalTransformer, self).__init__()

        # Zamansal sırayı öğrenmesi için Pozisyonel Kodlama ekliyoruz
        self.pos_embedding = nn.Parameter(torch.zeros(1, 100, embedding_dim))

        encoder_layer = nn.TransformerEncoderLayer(
            d_model=embedding_dim, nhead=num_heads,
            dim_feedforward=embedding_dim * 2, batch_first=True
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.classifier = nn.Linear(embedding_dim, num_classes)

    def forward(self, x):
        # x shape: [Batch, Time_Steps, embedding_dim]
        batch_size, seq_len, _ = x.size()
        x = x + self.pos_embedding[:, :seq_len, :]
        x = self.transformer(x)
        out = self.classifier(x) # Çıktı: [Batch, Time_Steps, num_classes]
        return out

class AudioScenePipeline(nn.Module):
    def __init__(self, feature_extractor, transformer_block):
        super(AudioScenePipeline, self).__init__()
        self.feature_extractor = feature_extractor
        self.transformer = transformer_block

    def forward(self, x, num_chunks=10):
        # x: [Batch, Freq, Total_Time]
        batch_size, freq, total_time = x.size(0), x.size(1), x.size(2)

        # Spektrogramı zaman ekseninde eşit parçalara bölüyoruz (Zaman Serisi Adımları)
        chunks = torch.chunk(x, chunks=num_chunks, dim=2)

        processed_chunks = [chunk.unsqueeze(1) for chunk in chunks] # Kanal boyutu ekleme
        stacked_chunks = torch.stack(processed_chunks, dim=0) # [Num_Chunks, Batch, 1, Freq, Chunk_Time]

        # Paralel işleme için Batch ve Chunk boyutlarını birleştiriyoruz
        flat_chunks = stacked_chunks.view(-1, 1, freq, chunks[0].size(2))

        # MobileNet ile özellik çıkarma
        features = self.feature_extractor(flat_chunks) # [Num_Chunks * Batch, embedding_dim]

        # Transformer için boyutları tekrar düzenleme: [Batch, Num_Chunks, embedding_dim]
        features = features.view(num_chunks, batch_size, -1).transpose(0, 1)

        # Transformer zamansal analiz
        output = self.transformer(features)
        return output

from torch.cuda.amp import autocast, GradScaler
import torch.optim as optim

def train_one_epoch(model, dataloader, optimizer, criterion, device):
    model.train()
    scaler = GradScaler() # FP16 Karışık Hassasiyet tetikleyici (A100 için şart)

    for batch_idx, (specs, labels) in enumerate(dataloader):
        specs = specs.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True) # Hafıza tasarrufu sağlar

        with autocast(): # Donanımsal Tensor çekirdeklerini optimize eder
            outputs = model(specs) # [Batch, Time_Steps, Num_Classes]

            # Zaman serisi boyunca her adım için kayıp hesabı
            time_steps = outputs.size(1)
            outputs_flat = outputs.view(-1, outputs.size(-1))
            labels_flat = labels.repeat_interleave(time_steps)

            loss = criterion(outputs_flat, labels_flat)

        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()

        if batch_idx % 20 == 0:
            print(f"Batch {batch_idx}/{len(dataloader)} -> Kayıp: {loss.item():.4f}")

# Cihaz Seçimi ve Başlatma
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Aktif Cihaz: {device}")

fe = MobileNetFeatureExtractor(embedding_dim=256)
tf = AudioTemporalTransformer(embedding_dim=256, num_classes=10)
model = AudioScenePipeline(fe, tf).to(device)

optimizer = optim.AdamW(model.parameters(), lr=1e-4, weight_decay=1e-2)
criterion = nn.CrossEntropyLoss()

# Veri setini bağlama adımı (Verileri yukarıdaki hücrelerden aldıktan sonra yorum satırını kaldırabilirsin)
# dataset = AcousticSceneDataset(audio_dir="./audio_data")
# High-RAM ve A100 için pin_memory ve num_workers değerlerini yüksek tutuyoruz
# dataloader = DataLoader(dataset, batch_size=64, shuffle=True, num_workers=4, pin_memory=True)

# train_one_epoch(model, dataloader, optimizer, criterion, device)
print("Eğitim mimarisi başarıyla kuruldu ve A100 için optimize edildi!")
import torch
import torch.nn as nn
import torchvision.models as models

class MobileNetFeatureExtractor(nn.Module):
    def __init__(self, embedding_dim=256):
        super(MobileNetFeatureExtractor, self).__init__()
        # Güncel PyTorch standartlarına uygun ağırlık yükleme biçimi
        weights = models.MobileNet_V3_Small_Weights.DEFAULT
        mobilenet = models.mobilenet_v3_small(weights=weights)

        # Giriş kanalını spektrogram için 1 yapıyoruz
        old_conv = mobilenet.features[0][0]
        new_conv = nn.Conv2d(1, old_conv.out_channels,
                             kernel_size=old_conv.kernel_size,
                             stride=old_conv.stride,
                             padding=old_conv.padding, bias=False)

        with torch.no_grad():
            new_conv.weight[:] = old_conv.weight.sum(dim=1, keepdim=True)
        mobilenet.features[0][0] = new_conv

        self.features = mobilenet.features
        self.pool = nn.AdaptiveAvgPool2d((1, 1))
        self.fc = nn.Linear(576, embedding_dim)

    def forward(self, x):
        x = self.features(x)
        x = self.pool(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)
        return x

class AudioTemporalTransformer(nn.Module):
    def __init__(self, embedding_dim=256, num_heads=4, num_layers=3, num_classes=10):
        super(AudioTemporalTransformer, self).__init__()

        self.pos_embedding = nn.Parameter(torch.zeros(1, 100, embedding_dim))

        encoder_layer = nn.TransformerEncoderLayer(
            d_model=embedding_dim, nhead=num_heads,
            dim_feedforward=embedding_dim * 2, batch_first=True
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.classifier = nn.Linear(embedding_dim, num_classes)

    def forward(self, x):
        batch_size, seq_len, _ = x.size()
        x = x + self.pos_embedding[:, :seq_len, :]
        x = self.transformer(x)
        out = self.classifier(x)
        return out

class AudioScenePipeline(nn.Module):
    def __init__(self, feature_extractor, transformer_block):
        super(AudioScenePipeline, self).__init__()
        self.feature_extractor = feature_extractor
        self.transformer = transformer_block

    def forward(self, x, num_chunks=10):
        batch_size, freq, total_time = x.size(0), x.size(1), x.size(2)

        # Sesi parçalara bölüyoruz
        chunks = torch.chunk(x, chunks=num_chunks, dim=2)
        actual_num_chunks = len(chunks) # Hatanın çözümü: Gerçek parça sayısını dinamik alıyoruz

        processed_chunks = [chunk.unsqueeze(1) for chunk in chunks]
        stacked_chunks = torch.stack(processed_chunks, dim=0)

        flat_chunks = stacked_chunks.view(-1, 1, freq, chunks[0].size(2))
        features = self.feature_extractor(flat_chunks)

        # Sabit num_chunks yerine actual_num_chunks kullanarak esnetiyoruz
        features = features.view(actual_num_chunks, batch_size, -1).transpose(0, 1)

        output = self.transformer(features)
        return output
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import random_split, DataLoader

# --- 1. AYARLAR VE VERİ HAZIRLIĞI ---
NUM_EPOCHS = 50
BATCH_SIZE = 128
LEARNING_RATE = 1e-3
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print(f"Eğitim Başlıyor! Aktif Donanım: {DEVICE}")

full_dataset = AcousticSceneDataset(audio_dir="./audio_data")

train_size = int(0.8 * len(full_dataset))
val_size = len(full_dataset) - train_size
train_dataset, val_dataset = random_split(full_dataset, [train_size, val_size])

train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True, num_workers=4, pin_memory=True)
val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False, num_workers=4, pin_memory=True)

num_classes = len(full_dataset.labels_map)
print(f"Toplam Veri: {len(full_dataset)} | Training: {train_size} | Validation: {val_size} | Sınıf Sayısı: {num_classes}")

# --- 2. MODEL VE OPTIMIZER ---
feature_extractor = MobileNetFeatureExtractor(embedding_dim=256)
transformer_block = AudioTemporalTransformer(embedding_dim=256, num_classes=num_classes)
model = AudioScenePipeline(feature_extractor, transformer_block).to(DEVICE)

criterion = nn.CrossEntropyLoss()
optimizer = optim.AdamW(model.parameters(), lr=LEARNING_RATE, weight_decay=1e-2)

scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', patience=3, factor=0.1)
scaler = torch.amp.GradScaler('cuda') # Güncel amp yapısı

# --- 3. EĞİTİM DÖNGÜSÜ ---
best_val_loss = float('inf')
history = {"train_loss": [], "val_loss": []}

for epoch in range(1, NUM_EPOCHS + 1):
    model.train()
    running_train_loss = 0.0

    for specs, labels in train_loader:
        specs = specs.to(DEVICE, non_blocking=True)
        labels = labels.to(DEVICE, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)

        with torch.amp.autocast('cuda'): # Güncel amp yapısı
            outputs = model(specs)
            time_steps = outputs.size(1)
            outputs_flat = outputs.view(-1, num_classes)
            labels_flat = labels.repeat_interleave(time_steps)

            loss = criterion(outputs_flat, labels_flat)

        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()

        running_train_loss += loss.item() * specs.size(0)

    epoch_train_loss = running_train_loss / len(train_loader.dataset)

    # DOĞRULAMA
    model.eval()
    running_val_loss = 0.0
    correct_preds = 0
    total_preds = 0

    with torch.no_grad():
        for specs, labels in val_loader:
            specs = specs.to(DEVICE, non_blocking=True)
            labels = labels.to(DEVICE, non_blocking=True)

            with torch.amp.autocast('cuda'):
                outputs = model(specs)
                time_steps = outputs.size(1)
                outputs_flat = outputs.view(-1, num_classes)
                labels_flat = labels.repeat_interleave(time_steps)

                loss = criterion(outputs_flat, labels_flat)

            running_val_loss += loss.item() * specs.size(0)

            _, predicted = torch.max(outputs_flat, 1)
            correct_preds += (predicted == labels_flat).sum().item()
            total_preds += labels_flat.size(0)

    epoch_val_loss = running_val_loss / len(val_loader.dataset)
    epoch_val_acc = (correct_preds / total_preds) * 100 if total_preds > 0 else 0.0

    history["train_loss"].append(epoch_train_loss)
    history["val_loss"].append(epoch_val_loss)
    scheduler.step(epoch_val_loss)

    print(f"Epoch [{epoch}/{NUM_EPOCHS}] -> Train Loss: {epoch_train_loss:.4f} | Val Loss: {epoch_val_loss:.4f} | Val Acc: %{epoch_val_acc:.2f}")

    if epoch_val_loss < best_val_loss:
        best_val_loss = epoch_val_loss
        torch.save(model.state_dict(), "en_iyi_akustik_model.pth")
        print("  --> [KAYIT] En iyi model ağırlıkları kaydedildi.")
