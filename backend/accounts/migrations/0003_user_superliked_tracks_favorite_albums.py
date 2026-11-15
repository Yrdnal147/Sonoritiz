from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_user_favorite_artists'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='favorite_albums',
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.AddField(
            model_name='user',
            name='superliked_tracks',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
