# Generated manually for User.favorite_artists synchronization

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='favorite_artists',
            field=models.JSONField(blank=True, default=list),
        ),
    ]
